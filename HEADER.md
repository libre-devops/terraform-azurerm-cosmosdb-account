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
