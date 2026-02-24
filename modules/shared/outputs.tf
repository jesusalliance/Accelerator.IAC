output "hub_vnet_id" {
  value       = azurerm_virtual_network.hub.id
  description = "Shared Hub VNet ID for peering from spokes"
}

output "hub_nat_gateway_id" {
  value       = azurerm_nat_gateway.nat[0].id
  description = "Primary NAT Gateway ID (for DEV/UAT)"
}

output "hub_nat_gateway_id_ha" {
  value       = azurerm_nat_gateway.nat[1].id
  description = "HA NAT Gateway ID (for PROD)"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server (e.g. felixjamacrs20260224.azurecr.io)"
}

output "log_analytics_id" {
  value       = azurerm_log_analytics_workspace.logs.id
  description = "Shared Log Analytics Workspace ID"
}

output "key_vault_id" {
  value       = azurerm_key_vault.kv.id
  description = "Shared Key Vault ID"
}