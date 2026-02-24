data "azurerm_client_config" "current" {}

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

# NAT Gateways (2 created; DEV/UAT use [0], PROD uses HA)
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

# ACR Premium
resource "azurerm_container_registry" "acr" {
  name                          = "acrjasharedunique"  # MUST be globally unique - change this
  resource_group_name           = var.rg_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  zone_redundancy_enabled       = true   # Recommended for shared
  public_network_access_enabled = false
  tags                          = var.tags
}

# Log Analytics
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-ja-shared"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# Key Vault RBAC + protection
resource "azurerm_key_vault" "kv" {
  name                        = "kv-ja-shared"
  resource_group_name         = var.rg_name
  location                    = var.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  tags                        = var.tags
}

# Private DNS Zones (example for Cosmos Mongo - add more as needed)
resource "azurerm_private_dns_zone" "cosmos_mongo" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = var.rg_name
  tags                = var.tags
}

# Front Door + WAF (basic; expand routing to point to envs)
resource "azurerm_frontdoor" "frontdoor" {
  name                                         = "fd-ja-shared"
  resource_group_name                          = var.rg_name
  enforce_backend_pools_certificate_name_check = false
  tags                                         = var.tags

  frontend_endpoint {
    name      = "frontend"
    host_name = "ja-mma-portal.azurefd.net"  # Update to custom domain
  }

  backend_pool {
    name = "default-backend"
    backend {
      host_header = "placeholder.azurewebsites.net"
      address     = "placeholder.azurewebsites.net"
      http_port   = 80
      https_port  = 443
    }
  }

  routing_rule {
    name               = "default"
    accepted_protocols = ["Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["frontend"]
    forwarding_configuration {
      forwarding_protocol = "MatchRequest"
      backend_pool_name   = "default-backend"
    }
  }
}

resource "azurerm_frontdoor_firewall_policy" "waf" {
  name                = "waf-ja-shared"
  resource_group_name = var.rg_name
  mode                = "Prevention"
  tags                = var.tags

  managed_rule {
    type    = "DefaultRuleSet"
    version = "2.1"  # OWASP-based DRS 2.1 (2026 standard)
  }
}