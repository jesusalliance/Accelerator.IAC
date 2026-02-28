# outputs.tf - Root-level outputs (moved here from main.tf to follow best practice)

output "dev_appgw_public_ip" {
  value       = module.dev.appgw_public_ip
  description = "Public IP address of the DEV Application Gateway"
}

output "dev_appgw_fqdn" {
  value       = module.dev.appgw_fqdn
  description = "FQDN of the DEV Application Gateway (if domain label configured)"
}

output "uat_appgw_public_ip" {
  value       = module.uat.appgw_public_ip
  description = "Public IP address of the UAT Application Gateway"
}

output "prod_appgw_public_ip" {
  value       = module.prod.appgw_public_ip
  description = "Public IP address of the PROD Application Gateway"
}

output "shared_acr_login_server" {
  value       = module.shared.acr_login_server
  description = "Login server endpoint for the shared Azure Container Registry"
}

output "dev_container_app_environment_id" {
  value       = module.dev.cae_id
  description = "Container App Environment ID for DEV"
}

output "dev_frontend_app_id" {
  value       = module.dev.frontend_app_id
  description = "Frontend Container App ID for DEV"
}