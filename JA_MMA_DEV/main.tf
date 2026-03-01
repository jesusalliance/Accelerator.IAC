# main.tf (root) - Jesus Alliance MMA Portal - FULL hub-spoke + exact PDF compliance (variable name fix)

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

data "terraform_remote_state" "shared" {
  backend = "local"
  config = {
    path = "../JA_MMA_SHARED/terraform.tfstate"  # adjust path if folders not siblings
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
  shared_rg_name            = data.terraform_remote_state.shared.outputs.shared_rg_name

  tags = {
    environment = "dev"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}


# Bidirectional Hub-Spoke VNet Peering (PDF sections 4.0 & 9.0 - REQUIRED)
# Place this AFTER all module calls (dev, uat, prod, shared) so outputs are available

resource "azurerm_virtual_network_peering" "hub_to_dev" {
  name                         = "peer-hub-to-dev"
  resource_group_name          = "rg-ja-shared"
  virtual_network_name         = "vnet-ja-hub"
  remote_virtual_network_id    = module.dev.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false          # ← ADD this line
  use_remote_gateways          = false          # ← ADD this line

  depends_on = [module.dev]                      # ← ADD this (optional but recommended)
}

resource "azurerm_virtual_network_peering" "dev_to_hub" {
  name                         = "peer-dev-to-hub"
  resource_group_name          = module.dev.rg_name
  virtual_network_name         = "vnet-ja-mma-dev"
  remote_virtual_network_id    = module.shared.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false          # ← ADD
  use_remote_gateways          = false          # ← ADD

  depends_on = [module.dev, module.shared]       # ← ADD
}

resource "azurerm_virtual_network_peering" "hub_to_uat" {
  name                         = "peer-hub-to-uat"
  resource_group_name          = "rg-ja-shared"
  virtual_network_name         = "vnet-ja-hub"
  remote_virtual_network_id    = module.uat.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [module.uat]
}

resource "azurerm_virtual_network_peering" "uat_to_hub" {
  name                         = "peer-uat-to-hub"
  resource_group_name          = module.uat.rg_name
  virtual_network_name         = "vnet-ja-mma-uat"
  remote_virtual_network_id    = module.shared.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [module.uat, module.shared]
}

resource "azurerm_virtual_network_peering" "hub_to_prod" {
  name                         = "peer-hub-to-prod"
  resource_group_name          = "rg-ja-shared"
  virtual_network_name         = "vnet-ja-hub"
  remote_virtual_network_id    = module.prod.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [module.prod]
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  name                         = "peer-prod-to-hub"
  resource_group_name          = module.prod.rg_name
  virtual_network_name         = "vnet-ja-mma-prod"
  remote_virtual_network_id    = module.shared.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [module.prod, module.shared]
}


# Root outputs
output "shared_acr_login_server" { value = module.shared.acr_login_server }
output "shared_firewall_private_ip" { value = module.shared.hub_firewall_private_ip }
output "shared_hub_vnet_id" { value = module.shared.hub_vnet_id }
output "dev_rg_name" { value = module.dev.rg_name }
output "uat_rg_name" { value = module.uat.rg_name }
output "prod_rg_name" { value = module.prod.rg_name }