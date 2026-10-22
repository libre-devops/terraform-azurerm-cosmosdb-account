# check blocks run after every plan and apply and warn (without blocking) when an invariant is
# violated.

# Key based access bypasses Entra ID and leaves no identity in the logs: flag any account that
# turns it back on.
check "entra_only_data_access" {
  assert {
    condition     = alltrue([for a in values(var.cosmosdb_accounts) : !a.local_authentication_enabled])
    error_message = "An account has local_authentication_enabled = true: account keys can reach its data without Entra ID."
  }
}

# Public network access with no IP range or virtual network rule admits every address (Entra ID is
# still required for data, but the endpoint is open).
check "public_access_is_narrowed" {
  assert {
    condition = alltrue([
      for a in values(var.cosmosdb_accounts) :
      !a.public_network_access_enabled || length(a.ip_range_filter) > 0 || length(a.virtual_network_rules) > 0
    ])
    error_message = "An account has public network access with no ip_range_filter or virtual_network_rules: any address can reach its endpoint."
  }
}
