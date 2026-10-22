# Changelog

All notable changes to this module are recorded here.

## 1.0.0

### Added
- Cosmos DB accounts keyed by name, with the full `azurerm_cosmosdb_account` surface: API and
  capacity by `kind` and `capabilities`, consistency, regions, backup (continuous or periodic),
  network rules, identity and customer managed keys, analytical store, CORS, and point in time
  restore into a new account.
- Secure defaults: key based (local) authentication off, account key metadata writes off, TLS 1.2,
  public network access off, continuous backup on the 7 day tier, free tier off.
- The accounts' data plane roles: custom role definitions and role assignments for API for Table
  accounts (through azapi, `tableRoleDefinitions` and `tableRoleAssignments` at api-version
  2026-03-15) and for NoSQL accounts (through azurerm), assigning the built-in Data Reader or Data
  Contributor by name or a custom role by key, at the account or a path below it.
- Outputs including each Table account's endpoint, derived from its document endpoint.
- Validations for impossible combinations (a serverless account in more than one region, Table
  roles on a NoSQL account, a role assignment naming both or neither role) and checks warning when
  key based access is turned back on or public access is left un-narrowed.
