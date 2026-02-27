# =============================================
# modules/environment/variables.tf
# Input variables for environment module
# =============================================

variable "environment" {
  type        = string
  description = "Environment name (dev, uat, prod)"
}

variable "rg_name" {
  type        = string
  description = "Resource Group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "vnet_cidr" {
  type        = string
  description = "CIDR for spoke VNet"
}

variable "az_count" {
  type    = number
  default = 1
}

variable "replica_min" {
  type = number
}

variable "replica_max" {
  type = number
}

variable "zone_redundancy_enabled" {
  type    = bool
  default = false
}

variable "hub_vnet_id" {
  type = string
}

variable "hub_firewall_private_ip" {
  type = string
}

variable "hub_firewall_id" {
  type = string
}

variable "acr_login_server" {
  type = string
}

variable "log_analytics_id" {
  type = string
}

variable "shared_cosmos_dns_zone_id" {
  type = string
}

variable "shared_acr_dns_zone_id" {
  type = string
}

variable "github_ci_principal_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "acr_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "ingress_type" {
  type    = string
  default = "app_gateway"
}

variable "cosmos_zone_redundant" {
  type    = bool
  default = true
}

variable "backup_retention_hours" {
  type    = number
  default = 720
}