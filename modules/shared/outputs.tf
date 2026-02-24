output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_nat_gateway_id" {
  value = azurerm_nat_gateway.nat[0].id  # Primary for DEV/UAT
}

output "hub_nat_gateway_id_ha" {
  value = azurerm_nat_gateway.nat[1].id  # HA for PROD
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

output "front_door_id" {
  value = azurerm_frontdoor.frontdoor.id
}