terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }
}

provider "azurerm" {
  features {}
}

# SHARED HUB
module "shared" {
  source = "./modules/shared"

  location = "centralus"
  rg_name  = "rg-ja-shared"

  tags = {
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
    environment = "shared"
  }
}

# DEV
module "dev" {
  source = "./modules/environment"

  environment                = "dev"
  rg_name                    = "rg-ja-mma-dev"
  location                   = "centralus"
  vnet_cidr                  = "10.10.0.0/21"
  az_count                   = 1
  replica_min                = 1
  replica_max                = 3
  zone_redundancy_enabled    = false

  hub_vnet_id                = module.shared.vnet_hub_id
  hub_firewall_private_ip    = module.shared.firewall_private_ip
  hub_firewall_id            = module.shared.firewall_id
  acr_login_server           = module.shared.acr_login_server
  log_analytics_id           = module.shared.log_analytics_id
  shared_cosmos_dns_zone_id  = module.shared.cosmos_dns_zone_id
  shared_acr_dns_zone_id     = module.shared.acr_dns_zone_id
  github_ci_principal_id     = module.shared.github_ci_identity_principal_id
  key_vault_id               = module.shared.key_vault_id
  acr_id                     = module.shared.acr_id

  tags = merge(
    module.shared.tags,
    { environment = "dev" }
  )

  deploy_app_gateway         = true
  appgw_sku                  = "Standard_v2"
  appgw_capacity             = 2
  appgw_domain_label         = "ja-mma-dev"
}

# UAT
module "uat" {
  source = "./modules/environment"

  environment                = "uat"
  rg_name                    = "rg-ja-mma-uat"
  location                   = "centralus"
  vnet_cidr                  = "10.20.0.0/21"
  az_count                   = 1
  replica_min                = 1
  replica_max                = 5
  zone_redundancy_enabled    = false

  hub_vnet_id                = module.shared.vnet_hub_id
  hub_firewall_private_ip    = module.shared.firewall_private_ip
  hub_firewall_id            = module.shared.firewall_id
  acr_login_server           = module.shared.acr_login_server
  log_analytics_id           = module.shared.log_analytics_id
  shared_cosmos_dns_zone_id  = module.shared.cosmos_dns_zone_id
  shared_acr_dns_zone_id     = module.shared.acr_dns_zone_id
  github_ci_principal_id     = module.shared.github_ci_identity_principal_id
  key_vault_id               = module.shared.key_vault_id
  acr_id                     = module.shared.acr_id

  tags = merge(
    module.shared.tags,
    { environment = "uat" }
  )

  deploy_app_gateway         = true
  appgw_sku                  = "WAF_v2"
  appgw_capacity             = 4
  appgw_domain_label         = "ja-mma-uat"
}

# PROD
module "prod" {
  source = "./modules/environment"

  environment                = "prod"
  rg_name                    = "rg-ja-mma-prod"
  location                   = "centralus"
  vnet_cidr                  = "10.30.0.0/21"
  az_count                   = 3
  replica_min                = 3
  replica_max                = 10
  zone_redundancy_enabled    = true

  hub_vnet_id                = module.shared.vnet_hub_id
  hub_firewall_private_ip    = module.shared.firewall_private_ip
  hub_firewall_id            = module.shared.firewall_id
  acr_login_server           = module.shared.acr_login_server
  log_analytics_id           = module.shared.log_analytics_id
  shared_cosmos_dns_zone_id  = module.shared.cosmos_dns_zone_id
  shared_acr_dns_zone_id     = module.shared.acr_dns_zone_id
  github_ci_principal_id     = module.shared.github_ci_identity_principal_id
  key_vault_id               = module.shared.key_vault_id
  acr_id                     = module.shared.acr_id

  tags = merge(
    module.shared.tags,
    { environment = "prod" }
  )

  deploy_app_gateway         = true
  appgw_sku                  = "WAF_v2"
  appgw_capacity             = 10
  appgw_domain_label         = "ja-mma-prod"
}