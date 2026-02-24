variable "environment" { type = string }
variable "rg_name" { type = string }
variable "location" { type = string }
variable "vnet_cidr" { type = string }
variable "az_count" { type = number }
variable "replica_min" { type = number }
variable "replica_max" { type = number }
variable "zone_redundancy_enabled" { type = bool }
variable "cosmos_zone_redundant" { type = bool }
variable "backup_retention_hours" { type = number }
variable "ingress_type" { type = string }
variable "tags" { type = map(string) }

variable "hub_vnet_id" { type = string }
variable "hub_nat_gateway_id" { type = string }
variable "acr_login_server" { type = string }
variable "log_analytics_id" { type = string }
variable "key_vault_id" { type = string }

# Made optional - classic Front Door deprecated; will use new Front Door later
variable "front_door_id" {
  type    = string
  default = ""  # Empty by default
}