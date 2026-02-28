# main.tf (root) - Jesus Alliance MMA Portal - Cleaned variable passing (only required args)

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "shared" {
  source = "./modules/shared"

  rg_name  = "rg-ja-shared"
  location = "centralus"
  tags = {
    environment = "shared"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
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
  cosmos_zone_redundant   = false
  backup_retention_hours  = 168
  appgw_sku               = "Standard_v2"
  appgw_capacity          = 2
  appgw_max_capacity      = 5

  hub_firewall_private_ip = module.shared.hub_firewall_private_ip
  acr_login_server        = module.shared.acr_login_server
  log_analytics_id        = module.shared.log_analytics_id
  github_ci_principal_id  = module.shared.github_ci_identity_principal_id
  shared_rg_name          = module.shared.rg_name

  tags = {
    environment = "dev"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }

  depends_on = [module.shared]
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
  cosmos_zone_redundant   = false
  backup_retention_hours  = 168
  appgw_sku               = "Standard_v2"
  appgw_capacity          = 2
  appgw_max_capacity      = 10

  hub_firewall_private_ip = module.shared.hub_firewall_private_ip
  acr_login_server        = module.shared.acr_login_server
  log_analytics_id        = module.shared.log_analytics_id
  github_ci_principal_id  = module.shared.github_ci_identity_principal_id
  shared_rg_name          = module.shared.rg_name

  tags = {
    environment = "uat"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }

  depends_on = [module.shared]
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
  cosmos_zone_redundant   = true
  backup_retention_hours  = 720
  appgw_sku               = "WAF_v2"
  appgw_capacity          = 3
  appgw_max_capacity      = 20

  hub_firewall_private_ip = module.shared.hub_firewall_private_ip
  acr_login_server        = module.shared.acr_login_server
  log_analytics_id        = module.shared.log_analytics_id
  github_ci_principal_id  = module.shared.github_ci_identity_principal_id
  shared_rg_name          = module.shared.rg_name

  tags = {
    environment = "prod"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }

  depends_on = [module.shared]
}

# ────────────────────────────────────────────────────────────────────────────────
# Bidirectional hub-spoke peering (required per PDF section 4.0 & 9.0)
# ────────────────────────────────────────────────────────────────────────────────

resource "azurerm_virtual_network_peering" "dev_to_hub" {
  name                         = "peer-dev-to-hub"
  resource_group_name          = module.dev.rg_name
  virtual_network_name         = "vnet-ja-mma-dev"
  remote_virtual_network_id    = module.shared.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "hub_to_dev" {
  name                         = "peer-hub-to-dev"
  resource_group_name          = module.shared.rg_name
  virtual_network_name         = "vnet-ja-hub"
  remote_virtual_network_id    = module.dev.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "uat_to_hub" {
  name                         = "peer-uat-to-hub"
  resource_group_name          = module.uat.rg_name
  virtual_network_name         = "vnet-ja-mma-uat"
  remote_virtual_network_id    = module.shared.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "hub_to_uat" {
  name                         = "peer-hub-to-uat"
  resource_group_name          = module.shared.rg_name
  virtual_network_name         = "vnet-ja-hub"
  remote_virtual_network_id    = module.uat.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  name                         = "peer-prod-to-hub"
  resource_group_name          = module.prod.rg_name
  virtual_network_name         = "vnet-ja-mma-prod"
  remote_virtual_network_id    = module.shared.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "hub_to_prod" {
  name                         = "peer-hub-to-prod"
  resource_group_name          = module.shared.rg_name
  virtual_network_name         = "vnet-ja-hub"
  remote_virtual_network_id    = module.prod.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# Root-level outputs (useful for verification / next steps)
output "shared_acr_login_server"       { value = module.shared.acr_login_server }
output "shared_firewall_private_ip"    { value = module.shared.hub_firewall_private_ip }
output "shared_hub_vnet_id"            { value = module.shared.hub_vnet_id }
output "dev_rg_name"                   { value = module.dev.rg_name }
output "uat_rg_name"                   { value = module.uat.rg_name }
output "prod_rg_name"                  { value = module.prod.rg_name }