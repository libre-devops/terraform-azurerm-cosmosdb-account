<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Cosmos DB Account

Cosmos DB accounts (API for Table or NoSQL, full surface) with Entra ID only data access, their data plane roles, and continuous backup.

[![CI](https://github.com/libre-devops/terraform-azurerm-cosmosdb-account/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-cosmosdb-account/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-cosmosdb-account?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-cosmosdb-account/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-cosmosdb-account)](./LICENSE)

---

## Overview

Cosmos DB accounts keyed by name, covering the full `azurerm_cosmosdb_account` surface (API and
capacity by `kind` and `capabilities`, consistency, regions, backup, network rules, identity and
customer managed keys, analytical store, CORS, and point in time restore into a new account).
Secure by default: **key based (local) authentication off**, so Entra ID is the only way to the
data and every access names its principal; account key metadata writes off; **TLS 1.2**; **public
network access off**; **continuous backup on the 7 day tier**, which has no backup storage charge;
free tier off. The resource group is passed by id.

The accounts' **data plane roles** live here too, because they are child resources of the account
that `azurerm_role_assignment` cannot make: `table_role_definitions` and `table_role_assignments`
for API for Table accounts (through azapi, as azurerm has no resource for them), and
`sql_role_definitions` and `sql_role_assignments` for NoSQL accounts. Assign the built-in **Cosmos
DB Built-in Data Reader** or **Contributor** by name, or the account's own custom roles by key, at
the account or a path below it.

Everything else composes from other modules: tables through the `cosmosdb-table` module, private
endpoints through `private-endpoint`, logs through `diagnostic-settings`, and ordinary Azure RBAC
(for example Cosmos DB Operator) through `role-assignment`, as the complete example shows.

> A Table account's endpoint is `https://<name>.table.cosmos.azure.com:443/` (output
> `table_endpoints`). `azure-data-tables` and the other Azure Tables SDKs use Entra ID against it
> unchanged: they ask for a `https://cosmos.azure.com/.default` token for that host by themselves.

## Usage

```hcl
module "cosmosdb" {
  source  = "libre-devops/cosmosdb-account/azurerm"
  version = "~> 1.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-dev-001"]
  location          = "uksouth"

  cosmosdb_accounts = {
    "cosmos-ldo-uks-dev-001" = {
      capabilities = ["EnableTable", "EnableServerless"]

      table_role_assignments = {
        app = {
          principal_id         = "<object id of the app's managed identity>"
          role_definition_name = "Cosmos DB Built-in Data Contributor"
        }
      }
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - a serverless API for Table account with the secure defaults.
- [`examples/complete`](./examples/complete) - a Table account with network rules, an identity and custom and built-in data roles, and a two region NoSQL account with 30 day continuous backup, with Cosmos DB Operator chained through the role-assignment module.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in the table
below so the reason is auditable.

| Trivy ID | Resource | Finding | Justification |
|----------|----------|---------|---------------|
| _None_   |          |         |               |

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here. Where the finding is out of this module's
scope, point the justification at the Libre DevOps module that does address it (for example the
private-endpoint module). Both the file and this table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0, < 2.0.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 2.13.0, < 3.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | >= 2.13.0, < 3.0.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azapi_resource.table_role_assignment](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.table_role_definition](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azurerm_cosmosdb_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account) | resource |
| [azurerm_cosmosdb_sql_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_sql_role_assignment) | resource |
| [azurerm_cosmosdb_sql_role_definition.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_sql_role_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cosmosdb_accounts"></a> [cosmosdb\_accounts](#input\_cosmosdb\_accounts) | Cosmos DB accounts to create, keyed by account name (3 to 44 lowercase letters, digits and<br/>hyphens). The full azurerm\_cosmosdb\_account surface, plus the account's own data plane roles:<br/>those are child resources of the account, and azurerm\_role\_assignment cannot make them.<br/><br/>The API comes from kind and capabilities: GlobalDocumentDB on its own is NoSQL; add EnableTable<br/>for Table, or use MongoDB, EnableGremlin or EnableCassandra. EnableServerless gives serverless<br/>capacity (one region only, no throughput limit).<br/><br/>Secure by default: key based (local) authentication off, so Entra ID is the only way in to the<br/>data; account key metadata writes off; TLS 1.2; public network access off; continuous backup<br/>on the 7 day tier (no backup storage charge); free tier off. Ordinary Azure RBAC (Cosmos DB<br/>Operator, say) composes through the role-assignment module, private endpoints through the<br/>private-endpoint module and logs through the diagnostic-settings module.<br/><br/>Data plane roles, keyed by a name you choose:<br/>  table\_role\_definitions  custom roles for a Table account: data\_actions, not\_data\_actions and<br/>                          assignable\_scope\_paths (below the account; [""] is the account)<br/>  table\_role\_assignments  principal\_id holds a built-in role (role\_definition\_name: Cosmos DB<br/>                          Built-in Data Reader or Contributor) or one of the account's custom<br/>                          roles (role\_definition\_key), at scope\_path below the account<br/>  sql\_role\_definitions / sql\_role\_assignments   the same for a NoSQL account<br/>Table roles are made through azapi (azurerm has no resource for them). | <pre>map(object({<br/>    kind         = optional(string, "GlobalDocumentDB")<br/>    offer_type   = optional(string, "Standard")<br/>    capabilities = optional(set(string), [])<br/><br/>    consistency_policy = optional(object({<br/>      consistency_level       = optional(string, "Session")<br/>      max_interval_in_seconds = optional(number)<br/>      max_staleness_prefix    = optional(number)<br/>    }), {})<br/><br/>    # Defaults to one region, the module's location. The first is the write region.<br/>    geo_locations = optional(list(object({<br/>      location          = optional(string)<br/>      failover_priority = optional(number, 0)<br/>      zone_redundant    = optional(bool, false)<br/>    })), [{}])<br/><br/>    backup = optional(object({<br/>      type                = optional(string, "Continuous")<br/>      tier                = optional(string, "Continuous7Days")<br/>      interval_in_minutes = optional(number)<br/>      retention_in_hours  = optional(number)<br/>      storage_redundancy  = optional(string)<br/>    }), {})<br/><br/>    local_authentication_enabled       = optional(bool, false)<br/>    access_key_metadata_writes_enabled = optional(bool, false)<br/>    minimal_tls_version                = optional(string, "Tls12")<br/><br/>    public_network_access_enabled     = optional(bool, false)<br/>    ip_range_filter                   = optional(set(string), [])<br/>    is_virtual_network_filter_enabled = optional(bool, false)<br/>    virtual_network_rules = optional(list(object({<br/>      id                                   = string<br/>      ignore_missing_vnet_service_endpoint = optional(bool, false)<br/>    })), [])<br/>    network_acl_bypass_for_azure_services = optional(bool, false)<br/>    network_acl_bypass_ids                = optional(list(string), [])<br/><br/>    automatic_failover_enabled       = optional(bool)<br/>    multiple_write_locations_enabled = optional(bool, false)<br/>    free_tier_enabled                = optional(bool, false)<br/>    analytical_storage_enabled       = optional(bool, false)<br/>    analytical_storage_schema_type   = optional(string)<br/>    burst_capacity_enabled           = optional(bool)<br/>    partition_merge_enabled          = optional(bool)<br/>    mongo_server_version             = optional(string)<br/>    total_throughput_limit           = optional(number)<br/><br/>    identity = optional(object({<br/>      type         = string<br/>      identity_ids = optional(set(string))<br/>    }))<br/>    default_identity_type = optional(string)<br/>    key_vault_key_id      = optional(string)<br/><br/>    cors_rule = optional(object({<br/>      allowed_headers    = list(string)<br/>      allowed_methods    = list(string)<br/>      allowed_origins    = list(string)<br/>      exposed_headers    = list(string)<br/>      max_age_in_seconds = optional(number)<br/>    }))<br/><br/>    # Point in time restore into this new account (create_mode = "Restore").<br/>    create_mode = optional(string)<br/>    restore = optional(object({<br/>      source_cosmosdb_account_id = string<br/>      restore_timestamp_in_utc   = string<br/>      tables_to_restore          = optional(list(string))<br/>      databases = optional(list(object({<br/>        name             = string<br/>        collection_names = optional(set(string))<br/>      })), [])<br/>      gremlin_databases = optional(list(object({<br/>        name        = string<br/>        graph_names = optional(list(string))<br/>      })), [])<br/>    }))<br/><br/>    table_role_definitions = optional(map(object({<br/>      role_name              = optional(string)<br/>      data_actions           = list(string)<br/>      not_data_actions       = optional(list(string), [])<br/>      assignable_scope_paths = optional(list(string), [""])<br/>    })), {})<br/>    table_role_assignments = optional(map(object({<br/>      principal_id         = string<br/>      role_definition_name = optional(string)<br/>      role_definition_key  = optional(string)<br/>      scope_path           = optional(string, "")<br/>    })), {})<br/>    sql_role_definitions = optional(map(object({<br/>      role_name              = optional(string)<br/>      data_actions           = list(string)<br/>      assignable_scope_paths = optional(list(string), [""])<br/>    })), {})<br/>    sql_role_assignments = optional(map(object({<br/>      principal_id         = string<br/>      role_definition_name = optional(string)<br/>      role_definition_key  = optional(string)<br/>      scope_path           = optional(string, "")<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the accounts, and their write region unless geo\_locations says otherwise. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Resource id of the resource group to create the accounts in. The name and subscription are parsed from it (pass the rg module's ids output). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for every account. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cosmosdb_accounts"></a> [cosmosdb\_accounts](#output\_cosmosdb\_accounts) | Map of account name to its key attributes: id, name, kind, endpoint, the Table endpoint (for Table accounts, else null), read and write endpoints, and the identity's principal id. |
| <a name="output_endpoints"></a> [endpoints](#output\_endpoints) | Map of account name to its endpoint (the document endpoint, https://<name>.documents.azure.com:443/). |
| <a name="output_identity_principal_ids"></a> [identity\_principal\_ids](#output\_identity\_principal\_ids) | Map of account name to its identity principal id (only accounts with an identity). |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of account name to its resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of account name to a { name, id } object, for passing where both are needed together. |
| <a name="output_names"></a> [names](#output\_names) | The account names. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group name parsed from resource\_group\_id. |
| <a name="output_sql_role_assignment_ids"></a> [sql\_role\_assignment\_ids](#output\_sql\_role\_assignment\_ids) | Map of "<account>\|<key>" to the NoSQL data plane role assignment id. |
| <a name="output_sql_role_definition_ids"></a> [sql\_role\_definition\_ids](#output\_sql\_role\_definition\_ids) | Map of "<account>\|<key>" to the NoSQL custom data plane role definition id. |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Subscription id parsed from resource\_group\_id. |
| <a name="output_table_endpoints"></a> [table\_endpoints](#output\_table\_endpoints) | Map of account name to its Table API endpoint (https://<name>.table.cosmos.azure.com:443/), for API for Table accounts only. azure-data-tables uses Entra ID against it with no other change. |
| <a name="output_table_role_assignment_ids"></a> [table\_role\_assignment\_ids](#output\_table\_role\_assignment\_ids) | Map of "<account>\|<key>" to the Table data plane role assignment id. |
| <a name="output_table_role_definition_ids"></a> [table\_role\_definition\_ids](#output\_table\_role\_definition\_ids) | Map of "<account>\|<key>" to the Table custom data plane role definition id. |
| <a name="output_tags"></a> [tags](#output\_tags) | The tags applied to the accounts. |
<!-- END_TF_DOCS -->
