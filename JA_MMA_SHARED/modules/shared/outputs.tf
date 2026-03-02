# modules/shared/outputs.tf

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "hub_firewall_id" {
  value = azurerm_firewall.hub.id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "log_analytics_id" {
  value = azurerm_log_analytics_workspace.logs.id
}

output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "github_ci_identity_principal_id" {
  value = azurerm_user_assigned_identity.github_ci.principal_id
}

output "cosmos_private_dns_zone_id" {
  value = azurerm_private_dns_zone.cosmos_mongo.id
}

output "acr_private_dns_zone_id" {
  value = azurerm_private_dns_zone.acr.id
}

output "frontdoor_profile_id" {
  value = azurerm_cdn_frontdoor_profile.ja.id
}

# NEW: required for spoke DNS links + peering
output "rg_name" {
  value = azurerm_resource_group.shared.name
}

# Add these at the end of modules/shared/outputs.tf

output "acr_registry_dns_zone_name" {
  description = "Name of the ACR registry Private DNS Zone (used by spokes)"
  value       = azurerm_private_dns_zone.acr.name  # Adjust resource name if different
}

output "acr_data_dns_zone_name" {
  description = "Name of the ACR data Private DNS Zone (used by spokes)"
  value       = azurerm_private_dns_zone.acr_data.name
}

# Optional — only add if spokes need ACR ID directly (rare)
output "acr_id" {
  description = "ID of the shared ACR (optional)"
  value       = azurerm_container_registry.acr.id
}

