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

# ────────────────────────────────────────────────────────────────────────────────
# New variables added for Cosmos autoscale, private endpoint, and NAT association
# ────────────────────────────────────────────────────────────────────────────────

variable "cosmos_max_throughput" {
  type        = number
  description = "Maximum RU/s for Cosmos DB autoscale (used on MongoDB database level)"
  default     = 4000  # Will be overridden in root main.tf per environment
}

variable "shared_cosmos_dns_zone_id" {
  type        = string
  description = "ID of the shared Private DNS Zone for Cosmos DB (privatelink.mongo.cosmos.azure.com) from rg-ja-shared"
}

variable "github_ci_principal_id" {
  type        = string
  description = "Principal ID of the shared GitHub CI managed identity"
}



# Optional: If you ever need to override NAT per env (e.g., PROD uses HA NAT), but your current hub_nat_gateway_id already handles it conditionally in root
# variable "shared_nat_gateway_id" { ... } → already covered by hub_nat_gateway_id