# =============================================
# modules/environment/variables.tf
# =============================================

variable "environment" {
  type        = string
  description = "dev, uat, prod"
}

variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_cidr" {
  type = string
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

variable "deploy_app_gateway" {
  type    = bool
  default = true
}

variable "appgw_sku" {
  type    = string
  default = "WAF_v2"
}

variable "appgw_capacity" {
  type    = number
  default = 2
}

variable "appgw_domain_label" {
  type    = string
  default = null
}