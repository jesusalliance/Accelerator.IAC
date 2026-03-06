# main.tf (DEV-root) - Jesus Alliance MMA Portal - FULL hub-spoke + exact PDF compliance (variable name fix)

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    environment = "dev"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}

data "terraform_remote_state" "shared" {
  backend = "local"
  config = {
    path = "..\\JA_MMA_SHARED\\terraform.tfstate"  # adjust path if folders not siblings
  }
}


provider "azurerm" {
  features {}
}


module "dev" {
  source = "./modules/environment"

  environment             = "dev"
  rg_name                 = "rg-ja-mma-dev"
  location                = "centralus"
  vnet_cidr               = "10.10.0.0/21"
  az_count                = 1
  replica_min             = 1
  replica_max             = 3
  zone_redundancy_enabled = false
  ingress_type            = "app_gateway"
  backup_retention_hours  = 168
  appgw_sku               = "Standard_v2"
  appgw_capacity          = 2
  appgw_max_capacity      = 5

  # UPDATED: Use remote state outputs from Shared folder instead of module.shared
  hub_vnet_id               = data.terraform_remote_state.shared.outputs.shared_hub_vnet_id
  hub_firewall_private_ip   = data.terraform_remote_state.shared.outputs.shared_firewall_private_ip
  hub_firewall_id           = data.terraform_remote_state.shared.outputs.hub_firewall_id
  acr_login_server          = data.terraform_remote_state.shared.outputs.shared_acr_login_server
  log_analytics_id          = data.terraform_remote_state.shared.outputs.shared_log_analytics_id
  shared_cosmos_dns_zone_id = data.terraform_remote_state.shared.outputs.shared_cosmos_dns_zone_id
  shared_acr_dns_zone_id    = data.terraform_remote_state.shared.outputs.shared_acr_dns_zone_id
  github_ci_principal_id    = data.terraform_remote_state.shared.outputs.shared_github_ci_principal_id
  key_vault_id              = data.terraform_remote_state.shared.outputs.shared_key_vault_id
  acr_id                    = data.terraform_remote_state.shared.outputs.shared_acr_id
  frontdoor_id              = data.terraform_remote_state.shared.outputs.shared_frontdoor_id
  shared_documentdb_dns_zone_id    = data.terraform_remote_state.shared.outputs.documentdb_private_dns_zone_id
  shared_documentdb_dns_zone_name  = data.terraform_remote_state.shared.outputs.documentdb_private_dns_zone_name
  shared_rg_name            = data.terraform_remote_state.shared.outputs.shared_rg_name

  tags = {
    environment = "dev"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}


# Spoke-to-hub peering for DEV
resource "azurerm_virtual_network_peering" "dev_to_hub" {
  name                         = "peering-dev-to-hub-link"
  resource_group_name          = module.dev.rg_name
  virtual_network_name         = "vnet-ja-mma-dev"
  remote_virtual_network_id    = data.terraform_remote_state.shared.outputs.shared_hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# DEV - ACR registry DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_registry_dev" {
  name                  = "link-dev-to-acr-registry"
  resource_group_name   = module.dev.rg_name          # Fixed from earlier error
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_registry_dns_zone_name
  virtual_network_id    = module.dev.vnet_id          # Fixed from earlier error
  registration_enabled  = false
  tags                  = var.tags                    # Now valid after declaring variable
}

# DEV - ACR data DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_data_dev" {
  name                  = "link-dev-to-acr-data"
  resource_group_name   = module.dev.rg_name
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_data_dns_zone_name
  virtual_network_id    = module.dev.vnet_id
  registration_enabled  = false
  tags                  = var.tags                    # Now valid
}


# Root outputs - DEV folder only
output "dev_rg_name" {
  value       = module.dev.rg_name
  description = "DEV resource group name"
}

output "dev_vnet_id" {
  value       = module.dev.vnet_id
  description = "DEV spoke VNet ID (for debugging or future use)"
}