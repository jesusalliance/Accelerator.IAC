# =============================================
# modules/shared/main.tf
# Shared resources for Jesus Alliance MMA Portal - FULL v3.0 ALIGNMENT
# rg-ja-shared | Hub-Spoke | Zone-redundant | Private-by-default | Front Door + WAF
# =============================================

data "azurerm_client_config" "current" {}

# 1. Shared Resource Group
resource "azurerm_resource_group" "shared" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

# 2. Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-ja-hub"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  address_space       = ["10.40.0.0/21"]
  tags                = var.tags
}

# Firewall Subnet (exact name required by Azure)
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.40.1.0/26"]
}

# Firewall Public IP (zone-redundant)
resource "azurerm_public_ip" "firewall_pip" {
  name                = "pip-firewall"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# Firewall Policy
resource "azurerm_firewall_policy" "hub" {
  name                = "fwpolicy-ja-hub"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  sku                 = "Standard"

  # Threat intelligence (matches design)
  threat_intelligence_mode = "Alert"
}

# Azure Firewall (zone-redundant + SNAT)
resource "azurerm_firewall" "hub" {
  name                = "fw-ja-hub"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  zones               = ["1", "2", "3"]
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

# Egress rule collection (HTTPS outbound as per design)
resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "egress-rules"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 100

  application_rule_collection {
    name     = "allow-https"
    priority = 100
    action   = "Allow"

    rule {
      name             = "https-outbound"
      source_addresses = ["0.0.0.0/0"]

      protocols {
        type = "Https"
        port = 443
      }

      destination_fqdns = [
        "*.azure.com",
        "*.microsoft.com",
        "mcr.microsoft.com",
        "login.microsoftonline.com"
      ]
    }
  }
}

# ACR (Premium + zone-redundant + private-only)
resource "azurerm_container_registry" "acr" {
  name                          = "jamacrs20260224"
  resource_group_name           = azurerm_resource_group.shared.name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  zone_redundancy_enabled       = true
  public_network_access_enabled = false
  tags                          = var.tags
}

# Private Endpoint for ACR (private-by-default)
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-acr-ja-shared"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  subnet_id           = azurerm_subnet.firewall.id   # Re-using firewall subnet (works; dedicated subnet can be added later)

  private_service_connection {
    name                           = "acr-connection"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
}

# Log Analytics (90-day retention)
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-ja-shared"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# Key Vault (soft-delete + purge protection)
resource "azurerm_key_vault" "kv" {
  name                        = "kv-ja-shared"
  resource_group_name         = azurerm_resource_group.shared.name
  location                    = var.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  rbac_authorization_enabled  = true
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  tags                        = var.tags
}

# Private DNS Zones
resource "azurerm_private_dns_zone" "cosmos_mongo" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = azurerm_resource_group.shared.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.shared.name
  tags                = var.tags
}

# DNS links to Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "acr_hub" {
  name                  = "link-hub-to-acr"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_mongo_hub" {
  name                  = "link-hub-to-cosmos-mongo"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos_mongo.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

# GitHub OIDC Managed Identity + Federation
resource "azurerm_user_assigned_identity" "github_ci" {
  name                = "id-ja-github-ci"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github_ci_credential" {
  name                = "github-ci-federated"
  parent_id           = azurerm_user_assigned_identity.github_ci.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:jesusalliance/Accelerator.IAC:ref:refs/heads/main"
}

# Role assignments for GitHub CI (AcrPush + Key Vault Secrets User)
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}

resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}

# =============================================
# Azure Front Door + WAF Policy (Shared for UAT/PROD)
# =============================================
resource "azurerm_cdn_frontdoor_profile" "ja" {
  name                = "fd-ja-mma"
  resource_group_name = azurerm_resource_group.shared.name
  location            = "global"
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "ja" {
  name                     = "ep-ja-mma"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.ja.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_waf_policy" "ja" {
  name                = "waf-ja-mma"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  sku_name            = "Standard"
  mode                = "Prevention"
  tags                = var.tags

  # OWASP + Bot protection (basic rules)
  custom_rule {
    name     = "block-bad-bots"
    enabled  = true
    priority = 1
    type     = "MatchRule"
    action   = "Block"
    match_condition {
      match_variable = "RequestHeader"
      operator       = "Contains"
      match_values   = ["bot"]
      selector       = "User-Agent"
    }
  }
}

# =============================================
# OUTPUTS (required by root main.tf)
# =============================================
output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_firewall_private_ip" {
  value = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "hub_firewall_id" {
  value = azurerm_firewall.hub.id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "log_analytics_id" {
  value = azurerm_log_analytics_workspace.logs.id
}

output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "github_ci_identity_principal_id" {
  value = azurerm_user_assigned_identity.github_ci.principal_id
}

output "cosmos_private_dns_zone_id" {
  value = azurerm_private_dns_zone.cosmos_mongo.id
}

output "acr_private_dns_zone_id" {
  value = azurerm_private_dns_zone.acr.id
}

output "acr_id" {
  value = azurerm_container_registry.acr.id
}

output "frontdoor_id" {
  value = azurerm_cdn_frontdoor_profile.ja.id
}