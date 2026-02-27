# =============================================
# main.tf (root)
# Jesus Alliance MMA Portal - Terraform Root Configuration
# Deploys Shared first, then DEV/UAT/PROD environments
# Region: Central US (centralus)
# Aligned with 3.0 design document (February 2026)
# =============================================

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

# =============================================
# SHARED INFRASTRUCTURE (deploy first)
# =============================================
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

# =============================================
# DEV Environment
# =============================================
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

  # Pass shared module outputs
  hub_vnet_id               = module.shared.hub_vnet_id
  hub_firewall_private_ip   = module.shared.hub_firewall_private_ip
  hub_firewall_id           = module.shared.hub_firewall_id
  acr_login_server          = module.shared.acr_login_server
  log_analytics_id          = module.shared.log_analytics_id
  shared_cosmos_dns_zone_id = module.shared.cosmos_private_dns_zone_id
  shared_acr_dns_zone_id    = module.shared.acr_private_dns_zone_id
  github_ci_principal_id    = module.shared.github_ci_identity_principal_id
  key_vault_id              = module.shared.key_vault_id

  # Define tags locally (no reference to module.shared.tags)
  tags = {
    environment = "dev"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }

  ingress_type           = "app_gateway"
  cosmos_zone_redundant  = false
  backup_retention_hours = 168

  depends_on = [module.shared]
}

# =============================================
# UAT Environment
# =============================================
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

  hub_vnet_id               = module.shared.hub_vnet_id
  hub_firewall_private_ip   = module.shared.hub_firewall_private_ip
  hub_firewall_id           = module.shared.hub_firewall_id
  acr_login_server          = module.shared.acr_login_server
  log_analytics_id          = module.shared.log_analytics_id
  shared_cosmos_dns_zone_id = module.shared.cosmos_private_dns_zone_id
  shared_acr_dns_zone_id    = module.shared.acr_private_dns_zone_id
  github_ci_principal_id    = module.shared.github_ci_identity_principal_id
  key_vault_id              = module.shared.key_vault_id

  tags = {
    environment = "uat"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }

  ingress_type           = "app_gateway"
  cosmos_zone_redundant  = false
  backup_retention_hours = 168

  depends_on = [module.shared]
}

# =============================================
# PROD Environment
# =============================================
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

  hub_vnet_id               = module.shared.hub_vnet_id
  hub_firewall_private_ip   = module.shared.hub_firewall_private_ip
  hub_firewall_id           = module.shared.hub_firewall_id
  acr_login_server          = module.shared.acr_login_server
  log_analytics_id          = module.shared.log_analytics_id
  shared_cosmos_dns_zone_id = module.shared.cosmos_private_dns_zone_id
  shared_acr_dns_zone_id    = module.shared.acr_private_dns_zone_id
  github_ci_principal_id    = module.shared.github_ci_identity_principal_id
  key_vault_id              = module.shared.key_vault_id

  tags = {
    environment = "prod"
    project     = "ja-mma-portal"
    owner       = "ja-portal-team"
  }

  ingress_type           = "app_gateway"
  cosmos_zone_redundant  = true
  backup_retention_hours = 720

  depends_on = [module.shared]
}

# =============================================
# ROOT-LEVEL OUTPUTS
# =============================================
output "shared_acr_login_server" {
  value       = module.shared.acr_login_server
  description = "Shared ACR login server"
}

output "shared_firewall_private_ip" {
  value       = module.shared.hub_firewall_private_ip
  description = "Private IP of hub Azure Firewall"
}

output "shared_hub_vnet_id" {
  value       = module.shared.hub_vnet_id
  description = "Hub VNet ID"
}

output "dev_rg_name" {
  value       = module.dev.rg_name
  description = "DEV Resource Group name"
}

output "uat_rg_name" {
  value       = module.uat.rg_name
  description = "UAT Resource Group name"
}

output "prod_rg_name" {
  value       = module.prod.rg_name
  description = "PROD Resource Group name"
}