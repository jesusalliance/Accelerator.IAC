# =============================================
# modules/environment/outputs.tf
# =============================================

output "rg_name" {
  value = azurerm_resource_group.env.name
}

output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "cae_id" {
  value = azurerm_container_app_environment.cae.id
}

output "frontend_app_id" {
  value = azurerm_container_app.frontend.id
}

output "backend_app_id" {
  value = azurerm_container_app.backend.id
}

output "appgw_id" {
  value = var.deploy_app_gateway ? try(azurerm_application_gateway.appgw[0].id, null) : null
}

output "appgw_public_ip" {
  value = var.deploy_app_gateway ? try(azurerm_public_ip.appgw_pip[0].ip_address, null) : null
}

output "appgw_fqdn" {
  value = var.deploy_app_gateway ? try(azurerm_public_ip.appgw_pip[0].fqdn, null) : null
}

output "appgw_public_ip_id" {
  value = var.deploy_app_gateway ? try(azurerm_public_ip.appgw_pip[0].id, null) : null
}