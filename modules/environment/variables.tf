# modules/environment/variables.tf

variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "rg_name" {
  description = "Resource Group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_cidr" {
  description = "Spoke VNet CIDR (e.g. 10.10.0.0/21)"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones (1 for DEV/UAT, 2+ for PROD)"
  type        = number
  default     = 1
}

variable "replica_min" {
  description = "Minimum replicas for Container Apps"
  type        = number
  default     = 1
}

variable "replica_max" {
  description = "Maximum replicas for Container Apps"
  type        = number
  default     = 10
}

variable "zone_redundancy_enabled" {
  description = "Enable zone redundancy where supported"
  type        = bool
  default     = false
}

variable "ingress_type" {
  description = "Ingress method: app_gateway, front_door, or direct (Container Apps public ingress)"
  type        = string
  default     = "app_gateway"

  validation {
    condition     = contains(["app_gateway", "front_door", "direct"], var.ingress_type)
    error_message = "ingress_type must be one of: app_gateway, front_door, direct."
  }
}

variable "cosmos_zone_redundant" {
  description = "Enable zone-redundant Cosmos DB (PROD only)"
  type        = bool
  default     = false
}

variable "backup_retention_hours" {
  description = "Cosmos DB periodic backup retention in hours"
  type        = number
  default     = 168
}

variable "appgw_sku" {
  description = "Application Gateway SKU (Standard_v2 or WAF_v2)"
  type        = string
  default     = "Standard_v2"
}

variable "appgw_capacity" {
  description = "Minimum capacity for App Gateway"
  type        = number
  default     = 2
}

variable "appgw_max_capacity" {
  description = "Maximum autoscale capacity for App Gateway"
  type        = number
  default     = 10
}

variable "frontdoor_id" {
  description = "Shared Azure Front Door profile ID (for UAT/PROD routing)"
  type        = string
  default     = null
}

# Passed from shared module
variable "hub_vnet_id" { type = string }
variable "hub_firewall_private_ip" { type = string }
variable "hub_firewall_id" { type = string }
variable "acr_login_server" { type = string }
variable "log_analytics_id" { type = string }
variable "shared_cosmos_dns_zone_id" { type = string }
variable "shared_acr_dns_zone_id" { type = string }
variable "github_ci_principal_id" { type = string }
variable "key_vault_id" { type = string }
variable "acr_id" { type = string }

variable "shared_rg_name" {
  description = "Shared resource group name (for Private DNS zone links)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}