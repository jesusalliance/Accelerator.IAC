terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.61"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  common_tags = {
    project     = "ja-mma-portal"
    cost-center = "ja-mma-portal"
    owner       = "ja-portal-team"
  }
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-ja-shared"
  location = var.location
  tags     = merge(local.common_tags, { environment = "shared", "backup-enabled" = "true", "backup-policy" = "daily" })
}

module "shared" {
  source   = "./modules/shared"
  rg_name  = azurerm_resource_group.shared.name
  location = var.location
  tags     = merge(local.common_tags, { environment = "shared", "backup-enabled" = "true", "backup-policy" = "daily" })
}

module "dev" {
  source = "./modules/environment"

  environment             = "dev"
  rg_name                 = "rg-ja-mma-dev"
  location                = var.location
  vnet_cidr               = "10.10.0.0/22"
  az_count                = 1
  replica_min             = 1
  replica_max             = 3
  zone_redundancy_enabled = false
  cosmos_zone_redundant   = false
  cosmos_max_throughput   = 4000               # DEV: low cost-optimized autoscale max
  shared_cosmos_dns_zone_id = module.shared.cosmos_private_dns_zone_id  # Add this for PE
  backup_retention_hours  = 168                # 7 days (your original)
  ingress_type            = "app_gateway"
  tags                    = merge(local.common_tags, { environment = "dev", "backup-enabled" = "true", "backup-policy" = "daily" })

  hub_vnet_id             = module.shared.hub_vnet_id
  hub_nat_gateway_id      = module.shared.hub_nat_gateway_id
  acr_login_server        = module.shared.acr_login_server
  log_analytics_id        = module.shared.log_analytics_id
  key_vault_id            = module.shared.key_vault_id

  depends_on = [module.shared]
}

module "uat" {
  source = "./modules/environment"

  environment             = "uat"
  rg_name                 = "rg-ja-mma-uat"
  location                = var.location
  vnet_cidr               = "10.20.0.0/22"
  az_count                = 1
  replica_min             = 1
  replica_max             = 5
  zone_redundancy_enabled = false
  cosmos_zone_redundant   = false
  cosmos_max_throughput   = 10000              # UAT: medium for validation
  shared_cosmos_dns_zone_id = module.shared.cosmos_private_dns_zone_id
  backup_retention_hours  = 168
  ingress_type            = "app_gateway"
  tags                    = merge(local.common_tags, { environment = "uat", "backup-enabled" = "true", "backup-policy" = "daily" })

  hub_vnet_id             = module.shared.hub_vnet_id
  hub_nat_gateway_id      = module.shared.hub_nat_gateway_id
  acr_login_server        = module.shared.acr_login_server
  log_analytics_id        = module.shared.log_analytics_id
  key_vault_id            = module.shared.key_vault_id

  depends_on = [module.shared]
}

module "prod" {
  source = "./modules/environment"

  environment             = "prod"
  rg_name                 = "rg-ja-mma-prod"
  location                = var.location
  vnet_cidr               = "10.30.0.0/22"
  az_count                = 2
  replica_min             = 1
  replica_max             = 20
  zone_redundancy_enabled = true
  cosmos_zone_redundant   = true
  cosmos_max_throughput   = 20000              # PROD: higher for scale/HA
  shared_cosmos_dns_zone_id = module.shared.cosmos_private_dns_zone_id
  backup_retention_hours  = 720                # 30 days (your original; aligns with doc)
  ingress_type            = "app_gateway"
  tags                    = merge(local.common_tags, { environment = "prod", "backup-enabled" = "true", "backup-policy" = "daily" })

  hub_vnet_id             = module.shared.hub_vnet_id
  hub_nat_gateway_id      = module.shared.hub_nat_gateway_id_ha  # HA for PROD
  acr_login_server        = module.shared.acr_login_server
  log_analytics_id        = module.shared.log_analytics_id
  key_vault_id            = module.shared.key_vault_id

  depends_on = [module.shared]
}