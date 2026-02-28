output "dev_appgw_public_ip" {
  value       = try(module.dev.appgw_public_ip, null)
  description = "Public IP address of the DEV Application Gateway (null if not deployed)"
}

output "dev_appgw_fqdn" {
  value       = try(module.dev.appgw_fqdn, null)
  description = "FQDN of the DEV Application Gateway (null if not deployed or no label)"
}

output "uat_appgw_public_ip" {
  value       = try(module.uat.appgw_public_ip, null)
  description = "Public IP address of the UAT Application Gateway (null if not deployed)"
}

output "prod_appgw_public_ip" {
  value       = try(module.prod.appgw_public_ip, null)
  description = "Public IP address of the PROD Application Gateway (null if not deployed)"
}

output "shared_acr_login_server" {
  value       = module.shared.acr_login_server
  description = "Login server endpoint for the shared Azure Container Registry"
}