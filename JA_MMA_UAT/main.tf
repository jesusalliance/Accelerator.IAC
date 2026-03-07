# main.tf (uat-root) - Jesus Alliance MMA Portal - FULL hub-spoke + exact PDF compliance (variable name fix)

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

# Option B: Fetch the DocumentDB vCore private DNS zone directly (bypasses shared outputs issue)
data "azurerm_private_dns_zone" "documentdb_vcore" {
  name                = "privatelink.mongocluster.cosmos.azure.com"
  resource_group_name = "rg-ja-shared"
}


module "uat" {
  source = "./modules/environment"

  environment             = "uat"
  rg_name                 = "rg-ja-mma-uat"
  location                = "centralus"
  vnet_cidr               = "10.20.0.0/21"
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
    

  shared_documentdb_dns_zone_id   = data.azurerm_private_dns_zone.documentdb_vcore.id
  shared_documentdb_dns_zone_name = data.azurerm_private_dns_zone.documentdb_vcore.name
  shared_rg_name            = data.terraform_remote_state.shared.outputs.shared_rg_name

  tags = {
    environment = "uat"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}


# Spoke-to-hub peering for uat
resource "azurerm_virtual_network_peering" "uat_to_hub" {
  name                         = "peering-uat-to-hub-link"
  resource_group_name          = module.uat.rg_name
  virtual_network_name         = "vnet-ja-mma-uat"
  remote_virtual_network_id    = data.terraform_remote_state.shared.outputs.shared_hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# uat - ACR registry DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_registry_uat" {
  name                  = "link-uat-to-acr-registry"
  resource_group_name   = module.uat.rg_name          # Fixed from earlier error
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_registry_dns_zone_name
  virtual_network_id    = module.uat.vnet_id          # Fixed from earlier error
  registration_enabled  = false
  tags                  = var.tags                    # Now valid after declaring variable
}

# uat - ACR data DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_data_uat" {
  name                  = "link-uat-to-acr-data"
  resource_group_name   = module.uat.rg_name
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_data_dns_zone_name
  virtual_network_id    = module.uat.vnet_id
  registration_enabled  = false
  tags                  = var.tags                    # Now valid
}


# Root outputs - uat folder only
output "uat_rg_name" {
  value       = module.uat.rg_name
  description = "uat resource group name"
}

output "uat_vnet_id" {
  value       = module.uat.vnet_id
  description = "uat spoke VNet ID (for debugging or future use)"
}