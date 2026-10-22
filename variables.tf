variable "cosmosdb_accounts" {
  description = <<-EOT
    Cosmos DB accounts to create, keyed by account name (3 to 44 lowercase letters, digits and
    hyphens). The full azurerm_cosmosdb_account surface, plus the account's own data plane roles:
    those are child resources of the account, and azurerm_role_assignment cannot make them.

    The API comes from kind and capabilities: GlobalDocumentDB on its own is NoSQL; add EnableTable
    for Table, or use MongoDB, EnableGremlin or EnableCassandra. EnableServerless gives serverless
    capacity (one region only, no throughput limit).

    Secure by default: key based (local) authentication off, so Entra ID is the only way in to the
    data; account key metadata writes off; TLS 1.2; public network access off; continuous backup
    on the 7 day tier (no backup storage charge); free tier off. Ordinary Azure RBAC (Cosmos DB
    Operator, say) composes through the role-assignment module, private endpoints through the
    private-endpoint module and logs through the diagnostic-settings module.

    Data plane roles, keyed by a name you choose:
      table_role_definitions  custom roles for a Table account: data_actions, not_data_actions and
                              assignable_scope_paths (below the account; [""] is the account)
      table_role_assignments  principal_id holds a built-in role (role_definition_name: Cosmos DB
                              Built-in Data Reader or Contributor) or one of the account's custom
                              roles (role_definition_key), at scope_path below the account
      sql_role_definitions / sql_role_assignments   the same for a NoSQL account
    Table roles are made through azapi (azurerm has no resource for them).
  EOT
  type = map(object({
    kind         = optional(string, "GlobalDocumentDB")
    offer_type   = optional(string, "Standard")
    capabilities = optional(set(string), [])

    consistency_policy = optional(object({
      consistency_level       = optional(string, "Session")
      max_interval_in_seconds = optional(number)
      max_staleness_prefix    = optional(number)
    }), {})

    # Defaults to one region, the module's location. The first is the write region.
    geo_locations = optional(list(object({
      location          = optional(string)
      failover_priority = optional(number, 0)
      zone_redundant    = optional(bool, false)
    })), [{}])

    backup = optional(object({
      type                = optional(string, "Continuous")
      tier                = optional(string, "Continuous7Days")
      interval_in_minutes = optional(number)
      retention_in_hours  = optional(number)
      storage_redundancy  = optional(string)
    }), {})

    local_authentication_enabled       = optional(bool, false)
    access_key_metadata_writes_enabled = optional(bool, false)
    minimal_tls_version                = optional(string, "Tls12")

    public_network_access_enabled     = optional(bool, false)
    ip_range_filter                   = optional(set(string), [])
    is_virtual_network_filter_enabled = optional(bool, false)
    virtual_network_rules = optional(list(object({
      id                                   = string
      ignore_missing_vnet_service_endpoint = optional(bool, false)
    })), [])
    network_acl_bypass_for_azure_services = optional(bool, false)
    network_acl_bypass_ids                = optional(list(string), [])

    automatic_failover_enabled       = optional(bool)
    multiple_write_locations_enabled = optional(bool, false)
    free_tier_enabled                = optional(bool, false)
    analytical_storage_enabled       = optional(bool, false)
    analytical_storage_schema_type   = optional(string)
    burst_capacity_enabled           = optional(bool)
    partition_merge_enabled          = optional(bool)
    mongo_server_version             = optional(string)
    total_throughput_limit           = optional(number)

    identity = optional(object({
      type         = string
      identity_ids = optional(set(string))
    }))
    default_identity_type = optional(string)
    key_vault_key_id      = optional(string)

    cors_rule = optional(object({
      allowed_headers    = list(string)
      allowed_methods    = list(string)
      allowed_origins    = list(string)
      exposed_headers    = list(string)
      max_age_in_seconds = optional(number)
    }))

    # Point in time restore into this new account (create_mode = "Restore").
    create_mode = optional(string)
    restore = optional(object({
      source_cosmosdb_account_id = string
      restore_timestamp_in_utc   = string
      tables_to_restore          = optional(list(string))
      databases = optional(list(object({
        name             = string
        collection_names = optional(set(string))
      })), [])
      gremlin_databases = optional(list(object({
        name        = string
        graph_names = optional(list(string))
      })), [])
    }))

    table_role_definitions = optional(map(object({
      role_name              = optional(string)
      data_actions           = list(string)
      not_data_actions       = optional(list(string), [])
      assignable_scope_paths = optional(list(string), [""])
    })), {})
    table_role_assignments = optional(map(object({
      principal_id         = string
      role_definition_name = optional(string)
      role_definition_key  = optional(string)
      scope_path           = optional(string, "")
    })), {})
    sql_role_definitions = optional(map(object({
      role_name              = optional(string)
      data_actions           = list(string)
      assignable_scope_paths = optional(list(string), [""])
    })), {})
    sql_role_assignments = optional(map(object({
      principal_id         = string
      role_definition_name = optional(string)
      role_definition_key  = optional(string)
      scope_path           = optional(string, "")
    })), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for name in keys(var.cosmosdb_accounts) : can(regex("^[a-z0-9][a-z0-9-]{1,42}[a-z0-9]$", name))])
    error_message = "Each account name must be 3 to 44 lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }

  validation {
    condition     = alltrue([for a in values(var.cosmosdb_accounts) : contains(["GlobalDocumentDB", "MongoDB", "Parse"], a.kind)])
    error_message = "kind must be GlobalDocumentDB, MongoDB or Parse."
  }

  validation {
    condition = alltrue([
      for a in values(var.cosmosdb_accounts) : contains(["BoundedStaleness", "ConsistentPrefix", "Eventual", "Session", "Strong"], a.consistency_policy.consistency_level)
    ])
    error_message = "consistency_policy.consistency_level must be BoundedStaleness, ConsistentPrefix, Eventual, Session or Strong."
  }

  validation {
    condition     = alltrue([for a in values(var.cosmosdb_accounts) : contains(["Tls", "Tls11", "Tls12"], a.minimal_tls_version)])
    error_message = "minimal_tls_version must be Tls, Tls11 or Tls12 (Tls12 is the default and the only one Microsoft recommends)."
  }

  validation {
    condition = alltrue([
      for a in values(var.cosmosdb_accounts) : a.backup.type == "Continuous" ? (
        contains(["Continuous7Days", "Continuous30Days"], coalesce(a.backup.tier, "Continuous7Days")) && a.backup.interval_in_minutes == null && a.backup.retention_in_hours == null
      ) : a.backup.type == "Periodic"
    ])
    error_message = "backup.type must be Continuous (with tier Continuous7Days or Continuous30Days, and no interval or retention) or Periodic."
  }

  validation {
    condition = alltrue([
      for a in values(var.cosmosdb_accounts) : !contains(a.capabilities, "EnableServerless") || (
        length(a.geo_locations) == 1 && !a.multiple_write_locations_enabled && a.total_throughput_limit == null
      )
    ])
    error_message = "A serverless account (EnableServerless) runs in one region only, with no multiple write locations and no total_throughput_limit."
  }

  validation {
    condition = alltrue(flatten([
      for a in values(var.cosmosdb_accounts) : [
        (length(a.table_role_definitions) + length(a.table_role_assignments) == 0 || contains(a.capabilities, "EnableTable")),
        (length(a.sql_role_definitions) + length(a.sql_role_assignments) == 0 || (
          a.kind == "GlobalDocumentDB" && length(setintersection(a.capabilities, ["EnableTable", "EnableGremlin", "EnableCassandra"])) == 0
        )),
      ]
    ]))
    error_message = "Table roles need an API for Table account (EnableTable), and NoSQL (sql) roles a NoSQL account (GlobalDocumentDB with no other API capability)."
  }

  validation {
    condition = alltrue(flatten([
      for a in values(var.cosmosdb_accounts) : [
        for r in concat(values(a.table_role_assignments), values(a.sql_role_assignments)) :
        can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", r.principal_id)) && (
          (r.role_definition_name == null) != (r.role_definition_key == null)
        )
      ]
    ]))
    error_message = "Each role assignment needs a principal_id (an object id, a GUID) and exactly one of role_definition_name (a built-in role) or role_definition_key (a custom role of the account)."
  }

  validation {
    condition = alltrue(flatten([
      for a in values(var.cosmosdb_accounts) : concat(
        [for r in values(a.table_role_assignments) : r.role_definition_name != null ? contains(["Cosmos DB Built-in Data Reader", "Cosmos DB Built-in Data Contributor"], r.role_definition_name) : r.role_definition_key != null ? contains(keys(a.table_role_definitions), r.role_definition_key) : false],
        [for r in values(a.sql_role_assignments) : r.role_definition_name != null ? contains(["Cosmos DB Built-in Data Reader", "Cosmos DB Built-in Data Contributor"], r.role_definition_name) : r.role_definition_key != null ? contains(keys(a.sql_role_definitions), r.role_definition_key) : false],
      )
    ]))
    error_message = "role_definition_name must be Cosmos DB Built-in Data Reader or Cosmos DB Built-in Data Contributor, and role_definition_key must name one of the account's custom role definitions."
  }
}

variable "location" {
  description = "Azure region for the accounts, and their write region unless geo_locations says otherwise."
  type        = string
}

variable "resource_group_id" {
  description = "Resource id of the resource group to create the accounts in. The name and subscription are parsed from it (pass the rg module's ids output)."
  type        = string

  validation {
    condition     = try(provider::azurerm::parse_resource_id(var.resource_group_id).resource_type, "") == "resourceGroups"
    error_message = "resource_group_id must be a resource group id of the form /subscriptions/<sub>/resourceGroups/<name>."
  }
}

variable "tags" {
  description = "Tags for every account."
  type        = map(string)
  default     = {}
}
