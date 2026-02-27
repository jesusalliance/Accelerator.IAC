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

# Uncomment when Cosmos resource is fully added
# output "cosmos_endpoint" {
#   value       = azurerm_cosmosdb_account.cosmos.endpoint
#   description = "Cosmos DB endpoint"
# }