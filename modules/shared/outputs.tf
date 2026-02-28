output "vnet_hub_id" {
  value = azurerm_virtual_network.hub.id
}

output "firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_id" {
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

output "acr_id" {
  value = azurerm_container_registry.acr.id
}