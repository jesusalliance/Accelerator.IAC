output "container_app_env_id" {
  value = azurerm_container_app_environment.cae.id
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}