# main.tf (PROD-root) - Jesus Alliance MMA Portal - FULL hub-spoke + exact PDF compliance (variable name fix)

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
    environment = "prod"
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



module "prod" {
  source = "./modules/environment"

  environment             = "prod"
  rg_name                 = "rg-ja-mma-prod"
  location                = "centralus"
  vnet_cidr               = "10.30.0.0/21"
  az_count                = 2
  replica_min             = 1
  replica_max             = 20
  zone_redundancy_enabled = true
  ingress_type            = "front_door"
  backup_retention_hours  = 720
  appgw_sku               = "WAF_v2"
  appgw_capacity          = 3
  appgw_max_capacity      = 20

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
  shared_rg_name            = data.terraform_remote_state.shared.outputs.shared_rg_name

  tags = {
    environment = "dev"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}

# Spoke-to-hub peering for PROD
resource "azurerm_virtual_network_peering" "prod_to_hub" {
  name                         = "peer-prod-to-hub"
  resource_group_name          = module.prod.rg_name
  virtual_network_name         = "vnet-ja-mma-prod"
  remote_virtual_network_id    = data.terraform_remote_state.shared.outputs.shared_hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# PROD - ACR registry DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_registry_prod" {
  name                  = "link-prod-to-acr-registry"
  resource_group_name   = module.prod.rg_name          # ← Correct: use module output
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_registry_dns_zone_name
  virtual_network_id    = module.prod.vnet_id          # ← Correct: use module output
  registration_enabled  = false
  tags                  = var.tags
}

# PROD - ACR data DNS zone link
resource "azurerm_private_dns_zone_virtual_network_link" "acr_data_prod" {
  name                  = "link-prod-to-acr-data"
  resource_group_name   = module.prod.rg_name
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_data_dns_zone_name
  virtual_network_id    = module.prod.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}


# Root outputs - PROD folder only
output "prod_rg_name" {
  value       = module.prod.rg_name
  description = "PROD resource group name"
}

output "prod_vnet_id" {
  value       = module.prod.vnet_id
  description = "PROD spoke VNet ID (for debugging or future use)"
}