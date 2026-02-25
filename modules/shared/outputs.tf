output "hub_vnet_id" {
  value       = azurerm_virtual_network.hub.id
}

output "hub_nat_gateway_id" {
  value       = azurerm_nat_gateway.nat[0].id
}

output "hub_nat_gateway_id_ha" {
  value       = azurerm_nat_gateway.nat[1].id
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
}

output "log_analytics_id" {
  value       = azurerm_log_analytics_workspace.logs.id
}

output "key_vault_id" {
  value       = azurerm_key_vault.kv.id
}

# NEW: OIDC GitHub CI/CD outputs
output "github_ci_identity_client_id" {
  value       = azurerm_user_assigned_identity.github_ci.client_id
  description = "Client ID of user-assigned identity for GitHub OIDC"
}

output "github_ci_identity_principal_id" {
  value       = azurerm_user_assigned_identity.github_ci.principal_id
  description = "Principal ID for role assignments"
}

output "github_ci_tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Azure AD Tenant ID for OIDC"
}

output "github_ci_subscription_id" {
  value       = data.azurerm_client_config.current.subscription_id
  description = "Azure Subscription ID for OIDC"
}

# NEW: Output for Cosmos DB Private DNS Zone (fixes Unsupported attribute error)
output "cosmos_private_dns_zone_id" {
  value       = azurerm_private_dns_zone.cosmos_mongo.id
  description = "ID of the shared Private DNS Zone for Cosmos DB MongoDB API (privatelink.mongo.cosmos.azure.com)"
}