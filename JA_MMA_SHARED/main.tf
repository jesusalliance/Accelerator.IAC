# main.tf (SHARED ENV root) - Jesus Alliance MMA Portal - FULL hub-spoke + exact PDF compliance (variable name fix)

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

#Read spoke VNets from their folders (for hub-to-spoke peering)
data "terraform_remote_state" "dev" {
  backend = "local"
  config = {
    path = "..//JA_MMA_DEV//terraform.tfstate"
  }
}

#data "terraform_remote_state" "uat" {
#  backend = "local"
#  config = {
#    path = "..\\JA_MMA_UAT\\terraform.tfstate"
# }
#}

#data "terraform_remote_state" "prod" {
#  backend = "local"
#  config = {
#    path = "..\\JA_MMA_PROD\\terraform.tfstate"
#  }
#}

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




# Root outputs - Shared-only (used by DEV/UAT/PROD folders via remote state)
output "shared_acr_login_server" {
  value       = module.shared.acr_login_server
  description = "ACR login server for image pulls"
}

output "shared_firewall_private_ip" {
  value       = module.shared.hub_firewall_private_ip
  description = "Azure Firewall private IP for UDR next-hop in spokes"
}

output "shared_hub_vnet_id" {
  value       = module.shared.hub_vnet_id
  description = "Hub VNet ID for bidirectional peering from spokes"
}

output "shared_cosmos_dns_zone_id" {
  value       = module.shared.cosmos_private_dns_zone_id
  description = "Shared Cosmos DB private DNS zone ID for spoke VNet links"
}

output "shared_acr_dns_zone_id" {
  value       = module.shared.acr_private_dns_zone_id
  description = "Shared ACR private DNS zone ID for spoke VNet links"
}

output "shared_log_analytics_id" {
  value       = module.shared.log_analytics_id
  description = "Log Analytics workspace ID for Container Apps logging"
}

output "shared_key_vault_id" {
  value       = module.shared.key_vault_id
  description = "Shared Key Vault ID for secrets access"
}

output "shared_acr_id" {
  value       = module.shared.acr_id
  description = "Shared ACR resource ID (for RBAC)"
}

output "shared_frontdoor_id" {
  value       = module.shared.frontdoor_profile_id
  description = "Shared Front Door profile ID (for UAT/PROD ingress)"
}

output "shared_github_ci_principal_id" {
  value       = module.shared.github_ci_identity_principal_id
  description = "GitHub CI managed identity principal ID (for OIDC/RBAC)"
}

output "shared_rg_name" {
  value       = "rg-ja-shared"
}

# Re-export only the outputs that spokes (DEV/UAT/PROD) actually need
output "acr_registry_dns_zone_name" {
  value       = module.shared.acr_registry_dns_zone_name
  description = "Name of the ACR registry Private DNS Zone (used by spokes for VNet links)"
}

output "acr_data_dns_zone_name" {
  value       = module.shared.acr_data_dns_zone_name
  description = "Name of the ACR data Private DNS Zone (used by spokes for VNet links)"
}

# Optional – only if spokes need ACR ID directly (rare)
output "acr_id" {
  value       = module.shared.acr_id
  description = "ID of the shared ACR (optional for spokes)"
}

#Hub-to-spoke peering (created in Shared folder after spokes exist)
 resource "azurerm_virtual_network_peering" "hub-to-dev" {
  name                         = "peering-hub-to-dev-link"
  resource_group_name          = "rg-ja-shared"
  virtual_network_name         = "vnet-ja-hub"
  remote_virtual_network_id    = data.terraform_remote_state.dev.outputs.dev_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  depends_on = [data.terraform_remote_state.dev]  # for hub_to_dev
}

#resource "azurerm_virtual_network_peering" "hub_to_uat" {
#  name                         = "peer-hub-to-uat"
#  resource_group_name          = "rg-ja-shared"
#  virtual_network_name         = "vnet-ja-hub"
#  remote_virtual_network_id    = data.terraform_remote_state.uat.outputs.uat_vnet_id
#  allow_virtual_network_access = true
#  allow_forwarded_traffic      = true
#  allow_gateway_transit        = false
#  use_remote_gateways          = false
#  depends_on = [data.terraform_remote_state.uat]  # for hub_to_uat
#}

#resource "azurerm_virtual_network_peering" "hub_to_prod" {
#  name                         = "peer-hub-to-prod"
#  resource_group_name          = "rg-ja-shared"
#  virtual_network_name         = "vnet-ja-hub"
#  remote_virtual_network_id    = data.terraform_remote_state.prod.outputs.prod_vnet_id
#  allow_virtual_network_access = true
#  allow_forwarded_traffic      = true
#  allow_gateway_transit        = false
#  use_remote_gateways          = false
#  depends_on = [data.terraform_remote_state.prod]  # for hub_to_prod
#}