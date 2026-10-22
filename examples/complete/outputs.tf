output "cosmosdb_accounts" {
  description = "Map of account name to its key attributes."
  value       = module.cosmosdb.cosmosdb_accounts
}

output "sql_role_assignment_ids" {
  description = "The NoSQL data plane role assignments."
  value       = module.cosmosdb.sql_role_assignment_ids
}

output "table_role_assignment_ids" {
  description = "The Table data plane role assignments."
  value       = module.cosmosdb.table_role_assignment_ids
}

output "table_role_definition_ids" {
  description = "The Table custom data plane role definitions."
  value       = module.cosmosdb.table_role_definition_ids
}
