# modules/environment/outputs.tf – FIXED: use correct exported attribute latest_revision_fqdn

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


output "private_app_subnet_id" {
  description = "Private-App subnet ID"
  value       = azurerm_subnet.private_app.id
}

output "documentdb_cluster_id" {
  description = "The resource ID of the DocumentDB MongoDB vCore cluster"
  value       = module.documentdb_mongo_cluster.mongo_cluster_id
}

output "documentdb_connection_string" {
  description = "Primary MongoDB connection string (private endpoint resolved; sensitive)"
  value       = module.documentdb_mongo_cluster.mongo_cluster_connection_string
  sensitive   = true
}

output "documentdb_connection_strings" {
  description = "All available connection strings from the service (may include alternatives)"
  value       = module.documentdb_mongo_cluster.mongo_cluster_connection_strings
  sensitive   = true
}

output "documentdb_endpoint" {
  description = "The private endpoint FQDN or similar (from properties if needed)"
  value       = try(module.documentdb_mongo_cluster.mongo_cluster_properties.properties.endpoints[0], null)
}