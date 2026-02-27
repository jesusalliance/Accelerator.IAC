# =============================================
# modules/shared/outputs.tf
# All outputs for the shared module
# =============================================

output "hub_vnet_id" {
  value       = azurerm_virtual_network.hub.id
  description = "ID of the hub VNet for peering from spokes"
}

output "hub_firewall_private_ip" {
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  description = "Private IP of the Azure Firewall (used in spoke UDRs)"
}

output "hub_firewall_id" {
  value       = azurerm_firewall.hub.id
  description = "Resource ID of the Azure Firewall"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "Login server for the shared ACR (e.g., jamacrs20260224.azurecr.io)"
}

output "log_analytics_id" {
  value       = azurerm_log_analytics_workspace.logs.id
  description = "ID of the shared Log Analytics workspace"
}

output "key_vault_id" {
  value       = azurerm_key_vault.kv.id
  description = "ID of the shared Key Vault"
}

output "github_ci_identity_principal_id" {
  value       = azurerm_user_assigned_identity.github_ci.principal_id
  description = "Principal ID of the GitHub OIDC managed identity"
}

output "cosmos_private_dns_zone_id" {
  value       = azurerm_private_dns_zone.cosmos_mongo.id
  description = "ID of the private DNS zone for Cosmos DB (Mongo API)"
}

output "acr_private_dns_zone_id" {
  value       = azurerm_private_dns_zone.acr.id
  description = "ID of the private DNS zone for ACR"
}

output "acr_id" {
  value       = azurerm_container_registry.acr.id
  description = "Resource ID of the shared ACR"
}