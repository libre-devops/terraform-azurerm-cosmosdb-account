locals {
  location     = lookup(var.regions, var.loc, "uksouth")
  rg_name      = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  table_name   = "cosmos-${var.short}-${var.loc}-${terraform.workspace}-002"
  nosql_name   = "cosmos-${var.short}-${var.loc}-${terraform.workspace}-003"
  deployer     = data.azurerm_client_config.current.object_id
  allowed_cidr = "203.0.113.0/24"
}

data "azurerm_client_config" "current" {}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  environment     = "prd"
  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-cosmosdb-account" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# Complete call:
#   - a serverless API for Table account, reachable from one address range, with a system assigned
#     identity, a custom read only data role and the deployer holding the built-in contributor role;
#   - a provisioned NoSQL account in two regions with continuous backup on the 30 day tier and
#     automatic failover, the deployer holding the built-in reader role on one database.
module "cosmosdb" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  cosmosdb_accounts = {
    (local.table_name) = {
      capabilities                  = ["EnableTable", "EnableServerless"]
      public_network_access_enabled = true
      ip_range_filter               = [local.allowed_cidr]
      identity                      = { type = "SystemAssigned" }

      table_role_definitions = {
        # readMetadata is needed by every SDK client; executeQuery lets it list as well as read.
        entity_reader = {
          role_name = "Table entity reader"
          data_actions = [
            "Microsoft.DocumentDB/databaseAccounts/readMetadata",
            "Microsoft.DocumentDB/databaseAccounts/tables/containers/executeQuery",
            "Microsoft.DocumentDB/databaseAccounts/tables/containers/entities/read",
          ]
        }
      }

      table_role_assignments = {
        deployer = {
          principal_id         = local.deployer
          role_definition_name = "Cosmos DB Built-in Data Contributor"
        }
      }
    }

    (local.nosql_name) = {
      consistency_policy = { consistency_level = "BoundedStaleness", max_interval_in_seconds = 300, max_staleness_prefix = 100000 }
      backup             = { tier = "Continuous30Days" }
      geo_locations = [
        { failover_priority = 0, zone_redundant = false },
        { location = "ukwest", failover_priority = 1 },
      ]
      automatic_failover_enabled = true

      sql_role_assignments = {
        deployer = {
          principal_id         = local.deployer
          role_definition_name = "Cosmos DB Built-in Data Reader"
          scope_path           = "/dbs/orders"
        }
      }
    }
  }
}

# Control plane access is ordinary Azure RBAC, so it chains through the role-assignment module:
# Cosmos DB Operator manages the accounts without reaching their data or keys.
module "role_assignments" {
  source  = "libre-devops/role-assignment/azurerm"
  version = "~> 4.1"

  role_assignments = {
    deployer_operator = {
      scope         = module.cosmosdb.ids[local.nosql_name]
      principal_ids = [local.deployer]
      role_names    = ["Cosmos DB Operator"]
      description   = "Manage the NoSQL account without data access."
    }
  }
}
