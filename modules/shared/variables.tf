# variables.tf - Input variables for the shared hub module
# All configurable values for hub resources (VNet, Firewall, ACR, Log Analytics, Key Vault, etc.)

variable "location" {
  type        = string
  description = "Azure region for all shared resources"
}

variable "rg_name" {
  type        = string
  description = "Name of the shared resource group"
}

variable "vnet_hub_cidr" {
  type        = string
  description = "CIDR block for the hub VNet"
  default     = "10.40.0.0/21"
}

variable "firewall_subnet_prefix" {
  type        = string
  description = "CIDR prefix for the Azure Firewall subnet (must be /26 or smaller)"
  default     = "10.40.1.0/26"
}

variable "acr_name" {
  type        = string
  description = "Name of the Azure Container Registry"
  default     = "jamacrs20260224"
}

variable "log_analytics_name" {
  type        = string
  description = "Name of the Log Analytics workspace"
  default     = "log-ja-shared"
}

variable "key_vault_name" {
  type        = string
  description = "Name of the Azure Key Vault"
  default     = "kv-ja-shared"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all shared resources"
  default     = {}
}