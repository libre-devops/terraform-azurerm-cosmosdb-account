output "cosmosdb_accounts" {
  description = "Map of account name to its key attributes: id, name, kind, endpoint, the Table endpoint (for Table accounts, else null), read and write endpoints, and the identity's principal id."
  value = { for k, a in azurerm_cosmosdb_account.this : k => {
    id                    = a.id
    name                  = a.name
    kind                  = a.kind
    endpoint              = a.endpoint
    table_endpoint        = contains(var.cosmosdb_accounts[k].capabilities, "EnableTable") ? replace(a.endpoint, ".documents.", ".table.cosmos.") : null
    read_endpoints        = a.read_endpoints
    write_endpoints       = a.write_endpoints
    identity_principal_id = try(a.identity[0].principal_id, null)
  } }
}

output "endpoints" {
  description = "Map of account name to its endpoint (the document endpoint, https://<name>.documents.azure.com:443/)."
  value       = { for k, a in azurerm_cosmosdb_account.this : k => a.endpoint }
}

output "identity_principal_ids" {
  description = "Map of account name to its identity principal id (only accounts with an identity)."
  value       = { for k, a in azurerm_cosmosdb_account.this : k => try(a.identity[0].principal_id, null) }
}

output "ids" {
  description = "Map of account name to its resource id."
  value       = { for k, a in azurerm_cosmosdb_account.this : k => a.id }
}

output "ids_zipmap" {
  description = "Map of account name to a { name, id } object, for passing where both are needed together."
  value       = { for k, a in azurerm_cosmosdb_account.this : k => { name = a.name, id = a.id } }
}

output "names" {
  description = "The account names."
  value       = keys(azurerm_cosmosdb_account.this)
}

output "resource_group_name" {
  description = "Resource group name parsed from resource_group_id."
  value       = local.resource_group_name
}

output "sql_role_assignment_ids" {
  description = "Map of \"<account>|<key>\" to the NoSQL data plane role assignment id."
  value       = { for k, r in azurerm_cosmosdb_sql_role_assignment.this : k => r.id }
}

output "sql_role_definition_ids" {
  description = "Map of \"<account>|<key>\" to the NoSQL custom data plane role definition id."
  value       = { for k, d in azurerm_cosmosdb_sql_role_definition.this : k => d.id }
}

output "subscription_id" {
  description = "Subscription id parsed from resource_group_id."
  value       = local.rg.subscription_id
}

output "table_endpoints" {
  description = "Map of account name to its Table API endpoint (https://<name>.table.cosmos.azure.com:443/), for API for Table accounts only. azure-data-tables uses Entra ID against it with no other change."
  value = {
    for k, a in azurerm_cosmosdb_account.this : k => replace(a.endpoint, ".documents.", ".table.cosmos.")
    if contains(var.cosmosdb_accounts[k].capabilities, "EnableTable")
  }
}

output "table_role_assignment_ids" {
  description = "Map of \"<account>|<key>\" to the Table data plane role assignment id."
  value       = { for k, r in azapi_resource.table_role_assignment : k => r.id }
}

output "table_role_definition_ids" {
  description = "Map of \"<account>|<key>\" to the Table custom data plane role definition id."
  value       = { for k, d in azapi_resource.table_role_definition : k => d.id }
}

output "tags" {
  description = "The tags applied to the accounts."
  value       = var.tags
}
