output "acr_login_server" {
  value       = module.shared.acr_login_server
  description = "ACR for pushing frontend/backend images"
}

output "log_analytics_workspace_id" {
  value = module.shared.log_analytics_id
}

output "key_vault_id" {
  value = module.shared.key_vault_id
}

output "front_door_id" {
  value = module.shared.front_door_id
}