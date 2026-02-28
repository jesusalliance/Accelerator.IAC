# modules/environment/outputs.tf - All outputs here (no duplicates in main.tf)

output "rg_name" {
  description = "Environment resource group name"
  value       = azurerm_resource_group.env.name
}

output "vnet_id" {
  description = "Spoke VNet ID"
  value       = azurerm_virtual_network.spoke.id
}

output "container_app_environment_id" {
  description = "Container Apps Environment ID"
  value       = azurerm_container_app_environment.cae.id
}

output "frontend_fqdn" {
  description = "Frontend Container App default FQDN (for Front Door origin if public)"
  value       = azurerm_container_app.frontend.configuration[0].ingress[0].fqdn
}

output "private_app_subnet_id" {
  description = "Private-App subnet ID (for reference)"
  value       = azurerm_subnet.private_app.id
}

output "cosmos_account_id" {
  description = "Cosmos DB account ID"
  value       = azurerm_cosmosdb_account.cosmos.id
}