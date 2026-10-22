output "ids" {
  description = "Map of account name to id."
  value       = module.cosmosdb.ids
}

output "table_endpoints" {
  description = "Map of account name to its Table endpoint."
  value       = module.cosmosdb.table_endpoints
}
