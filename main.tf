# Cosmos DB accounts keyed by name, with the full azurerm_cosmosdb_account surface and secure
# defaults: Entra ID only data access (local authentication and key metadata writes off), TLS 1.2,
# public network access off, and continuous backup on the free 7 day tier. The resource group is
# passed by id and parsed. The accounts' own data plane roles live here too, because they are child
# resources of the account that azurerm_role_assignment cannot make: Table roles through azapi
# (azurerm has no resource for them), NoSQL roles through azurerm.
resource "azurerm_cosmosdb_account" "this" {
  for_each = var.cosmosdb_accounts

  name                = each.key
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = var.tags

  kind       = each.value.kind
  offer_type = each.value.offer_type

  local_authentication_enabled       = each.value.local_authentication_enabled
  access_key_metadata_writes_enabled = each.value.access_key_metadata_writes_enabled
  minimal_tls_version                = each.value.minimal_tls_version

  public_network_access_enabled         = each.value.public_network_access_enabled
  ip_range_filter                       = each.value.ip_range_filter
  is_virtual_network_filter_enabled     = each.value.is_virtual_network_filter_enabled
  network_acl_bypass_for_azure_services = each.value.network_acl_bypass_for_azure_services
  network_acl_bypass_ids                = each.value.network_acl_bypass_ids

  automatic_failover_enabled       = each.value.automatic_failover_enabled
  multiple_write_locations_enabled = each.value.multiple_write_locations_enabled
  free_tier_enabled                = each.value.free_tier_enabled
  analytical_storage_enabled       = each.value.analytical_storage_enabled
  burst_capacity_enabled           = each.value.burst_capacity_enabled
  partition_merge_enabled          = each.value.partition_merge_enabled
  mongo_server_version             = each.value.mongo_server_version
  default_identity_type            = each.value.default_identity_type
  key_vault_key_id                 = each.value.key_vault_key_id
  create_mode                      = each.value.create_mode

  dynamic "capabilities" {
    for_each = each.value.capabilities
    content {
      name = capabilities.value
    }
  }

  consistency_policy {
    consistency_level       = each.value.consistency_policy.consistency_level
    max_interval_in_seconds = each.value.consistency_policy.max_interval_in_seconds
    max_staleness_prefix    = each.value.consistency_policy.max_staleness_prefix
  }

  dynamic "geo_location" {
    for_each = each.value.geo_locations
    content {
      location          = coalesce(geo_location.value.location, var.location)
      failover_priority = geo_location.value.failover_priority
      zone_redundant    = geo_location.value.zone_redundant
    }
  }

  backup {
    type                = each.value.backup.type
    tier                = each.value.backup.type == "Continuous" ? each.value.backup.tier : null
    interval_in_minutes = each.value.backup.interval_in_minutes
    retention_in_hours  = each.value.backup.retention_in_hours
    storage_redundancy  = each.value.backup.storage_redundancy
  }

  dynamic "virtual_network_rule" {
    for_each = each.value.virtual_network_rules
    content {
      id                                   = virtual_network_rule.value.id
      ignore_missing_vnet_service_endpoint = virtual_network_rule.value.ignore_missing_vnet_service_endpoint
    }
  }

  dynamic "identity" {
    for_each = each.value.identity != null ? [each.value.identity] : []
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "capacity" {
    for_each = each.value.total_throughput_limit != null ? [each.value.total_throughput_limit] : []
    content {
      total_throughput_limit = capacity.value
    }
  }

  dynamic "analytical_storage" {
    for_each = each.value.analytical_storage_schema_type != null ? [each.value.analytical_storage_schema_type] : []
    content {
      schema_type = analytical_storage.value
    }
  }

  dynamic "cors_rule" {
    for_each = each.value.cors_rule != null ? [each.value.cors_rule] : []
    content {
      allowed_headers    = cors_rule.value.allowed_headers
      allowed_methods    = cors_rule.value.allowed_methods
      allowed_origins    = cors_rule.value.allowed_origins
      exposed_headers    = cors_rule.value.exposed_headers
      max_age_in_seconds = cors_rule.value.max_age_in_seconds
    }
  }

  dynamic "restore" {
    for_each = each.value.restore != null ? [each.value.restore] : []
    content {
      source_cosmosdb_account_id = restore.value.source_cosmosdb_account_id
      restore_timestamp_in_utc   = restore.value.restore_timestamp_in_utc
      tables_to_restore          = restore.value.tables_to_restore

      dynamic "database" {
        for_each = restore.value.databases
        content {
          name             = database.value.name
          collection_names = database.value.collection_names
        }
      }

      dynamic "gremlin_database" {
        for_each = restore.value.gremlin_databases
        content {
          name        = gremlin_database.value.name
          graph_names = gremlin_database.value.graph_names
        }
      }
    }
  }
}

resource "azapi_resource" "table_role_definition" {
  for_each = local.table_role_definitions

  type      = "Microsoft.DocumentDB/databaseAccounts/tableRoleDefinitions@2026-03-15"
  name      = each.value.id
  parent_id = azurerm_cosmosdb_account.this[each.value.account].id

  body = {
    properties = {
      roleName         = coalesce(each.value.role_name, each.value.key)
      type             = "CustomRole"
      assignableScopes = [for path in each.value.assignable_scope_paths : "${azurerm_cosmosdb_account.this[each.value.account].id}${path}"]
      permissions = [
        {
          dataActions = each.value.data_actions
        }
      ]
    }
  }
}

resource "azapi_resource" "table_role_assignment" {
  for_each = local.table_role_assignments

  type      = "Microsoft.DocumentDB/databaseAccounts/tableRoleAssignments@2026-03-15"
  name      = each.value.id
  parent_id = azurerm_cosmosdb_account.this[each.value.account].id

  body = {
    properties = {
      principalId = each.value.principal_id
      scope       = "${azurerm_cosmosdb_account.this[each.value.account].id}${each.value.scope_path}"
      roleDefinitionId = (
        each.value.role_definition_key != null
        ? azapi_resource.table_role_definition["${each.value.account}|${each.value.role_definition_key}"].id
        : "${azurerm_cosmosdb_account.this[each.value.account].id}/tableRoleDefinitions/${local.built_in_data_roles[each.value.role_definition_name]}"
      )
    }
  }
}

resource "azurerm_cosmosdb_sql_role_definition" "this" {
  for_each = local.sql_role_definitions

  role_definition_id  = each.value.id
  name                = coalesce(each.value.role_name, each.value.key)
  resource_group_name = local.resource_group_name
  account_name        = azurerm_cosmosdb_account.this[each.value.account].name
  type                = "CustomRole"
  assignable_scopes   = [for path in each.value.assignable_scope_paths : "${azurerm_cosmosdb_account.this[each.value.account].id}${path}"]

  permissions {
    data_actions = each.value.data_actions
  }
}

resource "azurerm_cosmosdb_sql_role_assignment" "this" {
  for_each = local.sql_role_assignments

  name                = each.value.id
  resource_group_name = local.resource_group_name
  account_name        = azurerm_cosmosdb_account.this[each.value.account].name
  principal_id        = each.value.principal_id
  scope               = "${azurerm_cosmosdb_account.this[each.value.account].id}${each.value.scope_path}"
  role_definition_id = (
    each.value.role_definition_key != null
    ? azurerm_cosmosdb_sql_role_definition.this["${each.value.account}|${each.value.role_definition_key}"].id
    : "${azurerm_cosmosdb_account.this[each.value.account].id}/sqlRoleDefinitions/${local.built_in_data_roles[each.value.role_definition_name]}"
  )
}
