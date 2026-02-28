# modules/shared/main.tf - FULL v3.0 UPDATE
# Includes Front Door + WAF, symmetric peering prep, GitHub OIDC

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "shared" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

# Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-ja-hub"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  address_space       = ["10.40.0.0/21"]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.40.1.0/26"]
}

# Azure Firewall (zone-redundant)
resource "azurerm_public_ip" "firewall_pip" {
  name                = "pip-firewall"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  name                = "fw-ja-hub"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

resource "azurerm_firewall_policy" "hub" { ... } # (same as before – omitted for brevity, keep your existing)

# ACR, Log Analytics, Key Vault, Private DNS Zones – (keep your existing blocks)

# === NEW: Azure Front Door + WAF (for UAT/PROD) ===
resource "azurerm_cdn_frontdoor_profile" "ja" {
  name                = "fd-ja-mma"
  resource_group_name = azurerm_resource_group.shared.name
  location            = "global"
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "ja" {
  name                = "ep-ja-mma"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.ja.id
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_waf_policy" "ja" {
  name                = "waf-ja-mma"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  sku_name            = "Standard"
  mode                = "Prevention"

  custom_rule {
    name     = "block-bad-bots"
    enabled  = true
    priority = 1
    type     = "MatchRule"
    action   = "Block"
    match_condition {
      match_variable     = "RequestHeader"
      operator           = "Contains"
      match_values       = ["bot"]
      selector           = "User-Agent"
    }
  }
}

# GitHub CI Identity (your existing block – unchanged)

# Outputs updated to match root expectations
output "hub_vnet_id" { value = azurerm_virtual_network.hub.id }
output "hub_firewall_private_ip" { value = azurerm_firewall.hub.ip_configuration[0].private_ip_address }
output "hub_firewall_id" { value = azurerm_firewall.hub.id }
output "acr_login_server" { value = azurerm_container_registry.acr.login_server }
output "log_analytics_id" { value = azurerm_log_analytics_workspace.logs.id }
output "key_vault_id" { value = azurerm_key_vault.kv.id }
output "github_ci_identity_principal_id" { value = azurerm_user_assigned_identity.github_ci.principal_id }
output "cosmos_private_dns_zone_id" { value = azurerm_private_dns_zone.cosmos_mongo.id }
output "acr_private_dns_zone_id" { value = azurerm_private_dns_zone.acr.id }
output "acr_id" { value = azurerm_container_registry.acr.id }
output "frontdoor_id" { value = azurerm_cdn_frontdoor_profile.ja.id }