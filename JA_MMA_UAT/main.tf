# main.tf (UAT-root) - Jesus Alliance MMA Portal - FULL hub-spoke + exact PDF compliance (variable name fix)

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
    environment = "uat"
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


module "uat" {
  source = "./modules/environment"

  environment             = "uat"
  rg_name                 = "rg-ja-mma-uat"
  location                = "centralus"
  vnet_cidr               = "10.20.0.0/21"
  az_count                = 1
  replica_min             = 1
  replica_max             = 5
  zone_redundancy_enabled = false
  ingress_type            = "front_door"
  backup_retention_hours  = 168
  appgw_sku               = "Standard_v2"
  appgw_capacity          = 2
  appgw_max_capacity      = 10

  hub_vnet_id               = module.shared.hub_vnet_id
  hub_firewall_private_ip   = module.shared.hub_firewall_private_ip
  hub_firewall_id           = module.shared.hub_firewall_id
  acr_login_server          = module.shared.acr_login_server
  log_analytics_id          = module.shared.log_analytics_id
  shared_cosmos_dns_zone_id = module.shared.cosmos_private_dns_zone_id
  shared_acr_dns_zone_id    = module.shared.acr_private_dns_zone_id
  github_ci_principal_id    = module.shared.github_ci_identity_principal_id
  key_vault_id              = module.shared.key_vault_id
  acr_id                    = module.shared.acr_id
  frontdoor_id              = module.shared.frontdoor_profile_id
  shared_rg_name            = "rg-ja-shared"

  tags = {
    environment = "uat"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}


# Spoke-to-hub peering for UAT
resource "azurerm_virtual_network_peering" "uat_to_hub" {
  name                         = "peer-uat-to-hub"
  resource_group_name          = module.uat.rg_name
  virtual_network_name         = "vnet-ja-mma-uat"
  remote_virtual_network_id    = data.terraform_remote_state.shared.outputs.shared_hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}


# UAT - ACR registry DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_registry_uat" {
  name                  = "link-uat-to-acr-registry"
  resource_group_name   = module.uat.rg_name          # ← Use module output/attribute
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_registry_dns_zone_name
  virtual_network_id    = module.uat.vnet_id          # ← Use module output/attribute
  registration_enabled  = false
  tags                  = var.tags
}

# UAT - ACR data DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_data_uat" {
  name                  = "link-uat-to-acr-data"
  resource_group_name   = module.uat.rg_name
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_data_dns_zone_name
  virtual_network_id    = module.uat.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}


# Root outputs - UAT folder only
output "uat_rg_name" {
  value       = module.uat.rg_name
  description = "UAT resource group name"
}

output "uat_vnet_id" {
  value       = module.uat.vnet_id
  description = "UAT spoke VNet ID (for debugging or future use)"
}