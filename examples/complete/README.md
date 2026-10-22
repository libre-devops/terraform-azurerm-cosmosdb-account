<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

A serverless API for Table account (one allowed address range, a system assigned identity, a
custom read only data role, and the deployer holding the built-in contributor role) and a two
region NoSQL account (continuous backup on the 30 day tier, automatic failover, the deployer
holding the built-in reader role on one database), with Cosmos DB Operator chained through the
role-assignment module. The environment comes from the Terraform workspace, not a variable. Run it
with `just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
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
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0, < 2.0.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 2.13.0, < 3.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cosmosdb"></a> [cosmosdb](#module\_cosmosdb) | ../../ | n/a |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_role_assignments"></a> [role\_assignments](#module\_role\_assignments) | libre-devops/role-assignment/azurerm | ~> 4.1 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cosmosdb_accounts"></a> [cosmosdb\_accounts](#output\_cosmosdb\_accounts) | Map of account name to its key attributes. |
| <a name="output_sql_role_assignment_ids"></a> [sql\_role\_assignment\_ids](#output\_sql\_role\_assignment\_ids) | The NoSQL data plane role assignments. |
| <a name="output_table_role_assignment_ids"></a> [table\_role\_assignment\_ids](#output\_table\_role\_assignment\_ids) | The Table data plane role assignments. |
| <a name="output_table_role_definition_ids"></a> [table\_role\_definition\_ids](#output\_table\_role\_definition\_ids) | The Table custom data plane role definitions. |
<!-- END_TF_DOCS -->
