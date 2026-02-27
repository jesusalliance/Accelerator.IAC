# modules/environment/outputs.tf

output "rg_name" {
  value       = azurerm_resource_group.env.name
  description = "Resource Group name for this environment"
}

output "vnet_id" {
  value       = azurerm_virtual_network.spoke.id
  description = "Spoke VNet ID"
}

output "cae_id" {
  value       = azurerm_container_app_environment.cae.id
  description = "Container App Environment ID"
}

output "frontend_app_id" {
  value       = azurerm_container_app.frontend.id
  description = "Frontend Container App ID"
}

output "backend_app_id" {
  value       = azurerm_container_app.backend.id
  description = "Backend Container App ID"
}

output "appgw_public_ip" {
  value       = azurerm_public_ip.appgw_pip.ip_address
  description = "Public IP of the Application Gateway"
}

output "appgw_fqdn" {
  value       = azurerm_public_ip.appgw_pip.dns_settings[0].fqdn  # If DNS configured; otherwise null
  description = "FQDN of the Application Gateway (if DNS set)"
}

# Uncomment when Cosmos resource is fully added
# output "cosmos_endpoint" {
#   value       = azurerm_cosmosdb_account.cosmos.endpoint
#   description = "Cosmos DB endpoint"
# }
