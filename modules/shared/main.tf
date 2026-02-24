# =============================================
# modules/shared/main.tf
# Shared resources for Jesus Alliance MMA Portal
# Centralized in rg-ja-shared (hub VNet, NAT, ACR, Log Analytics, Key Vault, Private DNS)
# Front Door (classic) removed due to Azure deprecation (new creations blocked since Apr 2025)
# =============================================

data "azurerm_client_config" "current" {}

# Resource Group is created in root main.tf (rg-ja-shared)
# All resources below are placed in var.rg_name = "rg-ja-shared"

# Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-ja-hub"
  resource_group_name = var.rg_name
  location            = var.location
  address_space       = ["10.40.0.0/22"]
  tags                = var.tags
}

resource "azurerm_subnet" "nat_egress" {
  name                 = "snet-nat-egress"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.40.0.0/24"]
}

# NAT Gateways – 2 created (1 for DEV/UAT usage, 2 for PROD HA)
resource "azurerm_public_ip" "nat_pip" {
  count               = 2
  name                = "pip-nat-${count.index + 1}"
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "nat" {
  count               = 2
  name                = "nat-ja-shared-${count.index + 1}"
  resource_group_name = var.rg_name
  location            = var.location
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_assoc" {
  count                = 2
  nat_gateway_id       = azurerm_nat_gateway.nat[count.index].id
  public_ip_address_id = azurerm_public_ip.nat_pip[count.index].id
}

# Azure Container Registry (ACR) – Premium tier, shared for all environments
# CHANGE THE NAME BELOW TO SOMETHING GLOBALLY UNIQUE IF YOU GET A NAME CONFLICT
resource "azurerm_container_registry" "acr" {
  name                          = "felixjamacrs20260224"   # ← MUST BE UNIQUE – change this if needed
  resource_group_name           = var.rg_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  zone_redundancy_enabled       = true
  public_network_access_enabled = false
  tags                          = var.tags
}

# Log Analytics Workspace – centralized logging/metrics
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-ja-shared"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# Azure Key Vault – shared secrets, RBAC scoped by environment
resource "azurerm_key_vault" "kv" {
  name                        = "kv-ja-shared"
  resource_group_name         = var.rg_name
  location                    = var.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  rbac_authorization_enabled  = true
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  tags                        = var.tags
}

# Private DNS Zone – example for Cosmos DB MongoDB API (add more zones later)
resource "azurerm_private_dns_zone" "cosmos_mongo" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = var.rg_name
  tags                = var.tags
}

# =============================================
# Front Door – REMOVED due to Azure deprecation (new creations blocked since Apr 2025)
# Use new Azure Front Door (Standard/Premium) instead – see below for future implementation
# =============================================

/*
# Example placeholder for new Azure Front Door (recommended migration path)
resource "azurerm_cdn_frontdoor_profile" "frontdoor" {
  name                = "fd-ja-shared"
  resource_group_name = var.rg_name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = "endpoint-jashared"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
  tags                     = var.tags
}

# ... add origin group, origins, routes, security policy/WAF when ready
*/