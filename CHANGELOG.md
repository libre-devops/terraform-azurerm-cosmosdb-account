# Changelog

All notable changes to this module are recorded here.

## 1.0.2

### Fixed
- A Table role assignment whose scope or principal changes is replaced rather than updated:
  Cosmos DB refuses either in place ("Updating Table Role Assignment Scope is not permitted. You
  may only update the associated Role Definition."). A change of role definition is still an
  update. Assignments that do not change are left alone.

## 1.0.1

### Fixed
- Table role definitions no longer send `notDataActions`: Azure Cosmos DB for Table's role based
  access control does not support it, and denies anything not listed in `dataActions` (Microsoft
  Learn, data plane security reference for Table). The `not_data_actions` attribute is removed
  from `table_role_definitions`; it could only ever be empty.
- The complete example's custom Table role includes `readMetadata`, which every SDK client needs,
  and `executeQuery`.

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
