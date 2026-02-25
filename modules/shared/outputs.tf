output "hub_vnet_id" {
  description = "ID of the shared hub VNet"
  value       = azurerm_virtual_network.hub.id
}

output "hub_nat_gateway_id" {
  description = "ID of the primary NAT Gateway (for DEV/UAT)"
  value       = azurerm_nat_gateway.nat[0].id
}

output "hub_nat_gateway_id_ha" {
  description = "ID of the secondary NAT Gateway (for PROD HA)"
  value       = azurerm_nat_gateway.nat[1].id
}

output "acr_login_server" {
  description = "Login server for the shared Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "log_analytics_id" {
  description = "ID of the shared Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.logs.id
}

output "key_vault_id" {
  description = "ID of the shared Key Vault"
  value       = azurerm_key_vault.kv.id
}

output "github_ci_identity_client_id" {
  description = "Client ID of user-assigned identity for GitHub OIDC"
  value       = azurerm_user_assigned_identity.github_ci.client_id
}

output "github_ci_identity_principal_id" {
  description = "Principal ID for role assignments"
  value       = azurerm_user_assigned_identity.github_ci.principal_id
}

output "github_ci_tenant_id" {
  description = "Azure AD Tenant ID for OIDC"
  value       = data.azurerm_client_config.current.tenant_id
}

output "github_ci_subscription_id" {
  description = "Azure Subscription ID for OIDC"
  value       = data.azurerm_client_config.current.subscription_id
}

# Critical fix: Output for Cosmos Private DNS Zone (used by environment modules for private endpoint)
output "cosmos_private_dns_zone_id" {
  description = "ID of the shared Private DNS Zone for Cosmos DB MongoDB API"
  value       = azurerm_private_dns_zone.cosmos_mongo.id
}