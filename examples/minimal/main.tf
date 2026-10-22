locals {
  location     = lookup(var.regions, var.loc, "uksouth")
  rg_name      = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  account_name = "cosmos-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# Minimal call: a serverless API for Table account with the secure defaults (Entra ID only data
# access, TLS 1.2, no public network access, continuous backup on the free 7 day tier).
module "cosmosdb" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  cosmosdb_accounts = {
    (local.account_name) = {
      capabilities = ["EnableTable", "EnableServerless"]
    }
  }
}
