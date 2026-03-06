# modules/environment/variables.tf - FULL FILE (all variables now declared to match root main.tf calls + internal usage)

variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "rg_name" {
  description = "Name of the environment resource group"
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
  description = "Number of AZs (1 for DEV/UAT, 2 for PROD)"
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
  description = "Enable zone redundancy (false for DEV/UAT, true for PROD)"
  type        = bool
}

variable "ingress_type" {
  description = "Ingress type: 'app_gateway' or 'front_door'"
  type        = string
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
  description = "Application Gateway minimum capacity"
  type        = number
}

variable "appgw_max_capacity" {
  description = "Application Gateway maximum capacity"
  type        = number
}

variable "hub_firewall_private_ip" {
  description = "Azure Firewall private IP in hub (used for UDR)"
  type        = string
}

variable "hub_vnet_id" {
  description = "Hub VNet ID (passed for root-level peering reference)"
  type        = string
}

variable "hub_firewall_id" {
  description = "Hub Firewall resource ID"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server for container images"
  type        = string
}

variable "log_analytics_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "shared_cosmos_dns_zone_id" {
  description = "Shared Cosmos DB private DNS zone ID"
  type        = string
}

variable "shared_acr_dns_zone_id" {
  description = "Shared ACR private DNS zone ID"
  type        = string
}

variable "github_ci_principal_id" {
  description = "GitHub CI managed identity principal ID for RBAC"
  type        = string
}

variable "key_vault_id" {
  description = "Shared Key Vault ID"
  type        = string
}

variable "acr_id" {
  description = "Shared ACR resource ID"
  type        = string
}

variable "frontdoor_id" {
  description = "Shared Front Door profile ID"
  type        = string
}

variable "shared_rg_name" {
  description = "Shared resource group name (rg-ja-shared) for DNS zone links"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
}

variable "shared_documentdb_dns_zone_id" {
  description = "Shared DocumentDB vCore private DNS zone ID"
  type        = string
}

variable "shared_documentdb_dns_zone_name" {
  description = "Shared DocumentDB vCore private DNS zone name"
  type        = string
}