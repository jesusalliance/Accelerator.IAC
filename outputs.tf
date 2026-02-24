output "shared_acr_login_server" {
  value       = module.shared.acr_login_server
  description = "ACR for pushing frontend/backend images"
}

output "shared_hub_vnet_id" {
  value       = module.shared.hub_vnet_id
  description = "Shared Hub VNet ID"
}

output "shared_log_analytics_id" {
  value       = module.shared.log_analytics_id
  description = "Shared Log Analytics Workspace ID"
}

output "shared_key_vault_id" {
  value       = module.shared.key_vault_id
  description = "Shared Key Vault ID"
}