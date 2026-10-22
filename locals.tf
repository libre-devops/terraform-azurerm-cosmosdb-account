locals {
  rg                  = provider::azurerm::parse_resource_id(var.resource_group_id)
  resource_group_name = local.rg.resource_group_name

  # The built-in data plane roles, by name. Both APIs give them the same ids.
  built_in_data_roles = {
    "Cosmos DB Built-in Data Reader"      = "00000000-0000-0000-0000-000000000001"
    "Cosmos DB Built-in Data Contributor" = "00000000-0000-0000-0000-000000000002"
  }

  # Data plane role definitions and assignments, flattened to one map per kind keyed
  # "<account>|<key>". Each is named by a GUID derived from that key, so the name is known at plan
  # and stays put.
  table_role_definitions = merge([
    for account, a in var.cosmosdb_accounts : {
      for key, d in a.table_role_definitions : "${account}|${key}" => merge(d, {
        account = account
        key     = key
        id      = uuidv5("url", "https://github.com/libre-devops/terraform-azurerm-cosmosdb-account/${account}/table-role-definitions/${key}")
      })
    }
  ]...)

  table_role_assignments = merge([
    for account, a in var.cosmosdb_accounts : {
      for key, r in a.table_role_assignments : "${account}|${key}" => merge(r, {
        account = account
        id      = uuidv5("url", "https://github.com/libre-devops/terraform-azurerm-cosmosdb-account/${account}/table-role-assignments/${key}")
      })
    }
  ]...)

  sql_role_definitions = merge([
    for account, a in var.cosmosdb_accounts : {
      for key, d in a.sql_role_definitions : "${account}|${key}" => merge(d, {
        account = account
        key     = key
        id      = uuidv5("url", "https://github.com/libre-devops/terraform-azurerm-cosmosdb-account/${account}/sql-role-definitions/${key}")
      })
    }
  ]...)

  sql_role_assignments = merge([
    for account, a in var.cosmosdb_accounts : {
      for key, r in a.sql_role_assignments : "${account}|${key}" => merge(r, {
        account = account
        id      = uuidv5("url", "https://github.com/libre-devops/terraform-azurerm-cosmosdb-account/${account}/sql-role-assignments/${key}")
      })
    }
  ]...)
}
