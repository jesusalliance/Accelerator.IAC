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
    environment = "prod"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }

  depends_on = [module.shared]
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
  resource_group_name   = module.prod.rg_name          # Fixed from earlier error
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_registry_dns_zone_name
  virtual_network_id    = module.prod.vnet_id          # Fixed from earlier error
  registration_enabled  = false
  tags                  = var.tags                    # Now valid after declaring variable
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_data_prod" {
  name                  = "link-prod-to-acr-data"
  resource_group_name   = azurerm_resource_group.prod.name
  private_dns_zone_name = data.terraform_remote_state.shared.outputs.acr_data_dns_zone_name
  virtual_network_id    = azurerm_virtual_network.prod.id
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