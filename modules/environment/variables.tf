# modules/environment/variables.tf - CLEAN VERSION (only variables actually used by the module)

variable "environment" {
  description = "Environment name (dev/uat/prod)"
  type        = string
}

variable "rg_name" {
  description = "Resource group name for this environment"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_cidr" {
  description = "VNet address space (e.g. 10.10.0.0/21)"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones (1 for DEV/UAT, 2 for PROD)"
  type        = number
}

variable "replica_min" {
  description = "Minimum Container App replicas"
  type        = number
}

variable "replica_max" {
  description = "Maximum Container App replicas"
  type        = number
}

variable "zone_redundancy_enabled" {
  description = "Enable zone redundancy (true for PROD)"
  type        = bool
}

variable "ingress_type" {
  description = "app_gateway or front_door"
  type        = string
  validation {
    condition     = contains(["app_gateway", "front_door"], var.ingress_type)
    error_message = "ingress_type must be 'app_gateway' or 'front_door'."
  }
}

variable "cosmos_zone_redundant" {
  description = "Enable zone redundancy for Cosmos DB"
  type        = bool
}

variable "backup_retention_hours" {
  description = "Cosmos DB backup retention in hours"
  type        = number
}

variable "appgw_sku" {
  description = "Application Gateway SKU (Standard_v2 or WAF_v2)"
  type        = string
}

variable "appgw_capacity" {
  description = "Minimum Application Gateway capacity"
  type        = number
}

variable "appgw_max_capacity" {
  description = "Maximum Application Gateway capacity"
  type        = number
}

variable "hub_firewall_private_ip" {
  description = "Private IP of the shared Azure Firewall (for UDR)"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server name"
  type        = string
}

variable "log_analytics_id" {
  description = "Log Analytics Workspace ID"
  type        = string
}

variable "github_ci_principal_id" {
  description = "GitHub CI managed identity principal ID"
  type        = string
}

variable "shared_rg_name" {
  description = "Name of the shared resource group (for DNS links)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}