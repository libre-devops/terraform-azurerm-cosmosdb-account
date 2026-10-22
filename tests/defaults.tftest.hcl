# Plan-time tests for the module. The azurerm and azapi providers are mocked, so no credentials,
# no features block and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azapi" {}

mock_provider "azurerm" {
  mock_resource "azurerm_cosmosdb_account" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.DocumentDB/databaseAccounts/cosmos-ldo-uks-tst-01"
      endpoint = "https://cosmos-ldo-uks-tst-01.documents.azure.com:443/"
    }
  }

  mock_resource "azurerm_cosmosdb_sql_role_definition" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.DocumentDB/databaseAccounts/cosmos-ldo-uks-tst-01/sqlRoleDefinitions/00000000-0000-0000-0000-0000000000c1"
    }
  }
}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"

  cosmosdb_accounts = {
    "cosmos-ldo-uks-tst-01" = {}
  }
}

run "creates_an_account_with_secure_defaults" {
  command = plan

  assert {
    condition = (
      !azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].local_authentication_enabled &&
      !azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].access_key_metadata_writes_enabled
    )
    error_message = "Accounts should default to Entra ID only data access, with key metadata writes off."
  }

  assert {
    condition = (
      azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].minimal_tls_version == "Tls12" &&
      !azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].public_network_access_enabled &&
      !azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].free_tier_enabled
    )
    error_message = "Accounts should default to TLS 1.2, no public network access and no free tier."
  }

  assert {
    condition = (
      one(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].backup).type == "Continuous" &&
      one(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].backup).tier == "Continuous7Days"
    )
    error_message = "Accounts should default to continuous backup on the 7 day tier."
  }

  assert {
    condition = (
      azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].kind == "GlobalDocumentDB" &&
      one(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].consistency_policy).consistency_level == "Session" &&
      one(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].geo_location).location == "uksouth" &&
      one(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].geo_location).failover_priority == 0
    )
    error_message = "Accounts should default to NoSQL, Session consistency and one region at the module's location."
  }

  assert {
    condition     = output.resource_group_name == "rg-ldo-uks-tst-001" && output.table_endpoints == {}
    error_message = "The resource group is parsed from its id, and a NoSQL account has no Table endpoint."
  }
}

run "a_serverless_table_account_with_built_in_and_custom_roles" {
  command = apply

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = {
        capabilities = ["EnableTable", "EnableServerless"]
        table_role_definitions = {
          reader = {
            role_name    = "Device intake reader"
            data_actions = ["Microsoft.DocumentDB/databaseAccounts/tables/containers/entities/read"]
          }
        }
        table_role_assignments = {
          app = {
            principal_id         = "11111111-1111-1111-1111-111111111111"
            role_definition_name = "Cosmos DB Built-in Data Contributor"
          }
          auditor = {
            principal_id        = "22222222-2222-2222-2222-222222222222"
            role_definition_key = "reader"
            scope_path          = "/dbs/TablesDB/colls/devices"
          }
        }
      }
    }
  }

  assert {
    condition     = toset([for c in azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].capabilities : c.name]) == toset(["EnableTable", "EnableServerless"])
    error_message = "The API and capacity come from the capabilities."
  }

  assert {
    condition = (
      azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|app"].body.properties.roleDefinitionId == "${azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].id}/tableRoleDefinitions/00000000-0000-0000-0000-000000000002" &&
      azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|app"].body.properties.scope == azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].id &&
      azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|app"].body.properties.principalId == "11111111-1111-1111-1111-111111111111"
    )
    error_message = "A built-in role is assigned by its well-known id, at the account by default."
  }

  assert {
    condition = (
      azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|auditor"].body.properties.roleDefinitionId == azapi_resource.table_role_definition["cosmos-ldo-uks-tst-01|reader"].id &&
      azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|auditor"].body.properties.scope == "${azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].id}/dbs/TablesDB/colls/devices"
    )
    error_message = "A custom role is assigned by its key, at the scope path below the account."
  }

  assert {
    condition = (
      azapi_resource.table_role_definition["cosmos-ldo-uks-tst-01|reader"].body.properties.roleName == "Device intake reader" &&
      jsonencode(azapi_resource.table_role_definition["cosmos-ldo-uks-tst-01|reader"].body.properties.assignableScopes) == jsonencode([azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].id])
    )
    error_message = "A custom role definition takes its name and is assignable at the account by default."
  }

  assert {
    condition     = jsonencode(azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|auditor"].replace_triggers_refs) == jsonencode(["properties.principalId", "properties.scope"])
    error_message = "A Table role assignment is replaced, not updated, when its principal or scope changes: Cosmos DB refuses either in place."
  }

  assert {
    condition     = jsonencode(keys(one(azapi_resource.table_role_definition["cosmos-ldo-uks-tst-01|reader"].body.properties.permissions))) == jsonencode(["dataActions"])
    error_message = "A Table role definition carries dataActions only: the service does not support notDataActions for Table roles."
  }

  assert {
    condition = (
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$", azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|app"].name)) &&
      azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|app"].name != azapi_resource.table_role_assignment["cosmos-ldo-uks-tst-01|auditor"].name
    )
    error_message = "Each role assignment is named by its own stable GUID."
  }

  assert {
    condition     = output.table_endpoints == { "cosmos-ldo-uks-tst-01" = "https://cosmos-ldo-uks-tst-01.table.cosmos.azure.com:443/" }
    error_message = "A Table account's endpoint is derived from its document endpoint."
  }
}

run "a_nosql_account_with_built_in_and_custom_roles" {
  command = apply

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = {
        sql_role_definitions = {
          writer = { data_actions = ["Microsoft.DocumentDB/databaseAccounts/readMetadata", "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*"] }
        }
        sql_role_assignments = {
          reader = { principal_id = "33333333-3333-3333-3333-333333333333", role_definition_name = "Cosmos DB Built-in Data Reader" }
          writer = { principal_id = "44444444-4444-4444-4444-444444444444", role_definition_key = "writer", scope_path = "/dbs/orders" }
        }
      }
    }
  }

  assert {
    condition = (
      azurerm_cosmosdb_sql_role_assignment.this["cosmos-ldo-uks-tst-01|reader"].role_definition_id == "${azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000001" &&
      azurerm_cosmosdb_sql_role_assignment.this["cosmos-ldo-uks-tst-01|writer"].role_definition_id == azurerm_cosmosdb_sql_role_definition.this["cosmos-ldo-uks-tst-01|writer"].id &&
      azurerm_cosmosdb_sql_role_assignment.this["cosmos-ldo-uks-tst-01|writer"].scope == "${azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].id}/dbs/orders"
    )
    error_message = "NoSQL roles are assigned by built-in id or custom key, at the scope path below the account."
  }

  assert {
    condition     = azurerm_cosmosdb_sql_role_definition.this["cosmos-ldo-uks-tst-01|writer"].name == "writer" && azurerm_cosmosdb_sql_role_definition.this["cosmos-ldo-uks-tst-01|writer"].type == "CustomRole"
    error_message = "A custom role's name defaults to its key."
  }
}

run "periodic_backup_and_a_second_region" {
  command = plan

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = {
        backup = { type = "Periodic", interval_in_minutes = 240, retention_in_hours = 8, storage_redundancy = "Geo" }
        geo_locations = [
          { failover_priority = 0, zone_redundant = true },
          { location = "ukwest", failover_priority = 1 },
        ]
        automatic_failover_enabled = true
      }
    }
  }

  assert {
    condition = (
      one(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].backup).type == "Periodic" &&
      one(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].backup).interval_in_minutes == 240 &&
      length(azurerm_cosmosdb_account.this["cosmos-ldo-uks-tst-01"].geo_location) == 2
    )
    error_message = "Periodic backup and a second region are passed through."
  }
}

run "rejects_a_bad_account_name" {
  command = plan

  variables {
    cosmosdb_accounts = { "Cosmos_Bad" = {} }
  }

  expect_failures = [var.cosmosdb_accounts]
}

run "rejects_a_serverless_account_in_two_regions" {
  command = plan

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = {
        capabilities  = ["EnableServerless"]
        geo_locations = [{ failover_priority = 0 }, { location = "ukwest", failover_priority = 1 }]
      }
    }
  }

  expect_failures = [var.cosmosdb_accounts]
}

run "rejects_table_roles_on_a_nosql_account" {
  command = plan

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = {
        table_role_assignments = { app = { principal_id = "11111111-1111-1111-1111-111111111111", role_definition_name = "Cosmos DB Built-in Data Contributor" } }
      }
    }
  }

  expect_failures = [var.cosmosdb_accounts]
}

run "rejects_a_role_assignment_naming_both_or_neither_role" {
  command = plan

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = {
        sql_role_assignments = {
          both    = { principal_id = "11111111-1111-1111-1111-111111111111", role_definition_name = "Cosmos DB Built-in Data Reader", role_definition_key = "x" }
          neither = { principal_id = "11111111-1111-1111-1111-111111111111" }
        }
      }
    }
  }

  expect_failures = [var.cosmosdb_accounts]
}

run "rejects_an_unknown_built_in_role_or_custom_key" {
  command = plan

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = {
        capabilities = ["EnableTable"]
        table_role_assignments = {
          owner = { principal_id = "11111111-1111-1111-1111-111111111111", role_definition_name = "Owner" }
          ghost = { principal_id = "11111111-1111-1111-1111-111111111111", role_definition_key = "missing" }
        }
      }
    }
  }

  expect_failures = [var.cosmosdb_accounts]
}

run "rejects_a_continuous_backup_with_periodic_settings" {
  command = plan

  variables {
    cosmosdb_accounts = {
      "cosmos-ldo-uks-tst-01" = { backup = { interval_in_minutes = 240 } }
    }
  }

  expect_failures = [var.cosmosdb_accounts]
}
