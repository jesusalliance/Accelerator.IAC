# modules/shared/main.tf - FINAL CLEAN VERSION (duplicate outputs removed - keep only in outputs.tf)

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

# Firewall Subnet
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.40.1.0/26"]
}

# Firewall Public IP
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

  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

# Azure Firewall
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

resource "azurerm_subnet" "private_endpoint" {
  name                                           = "PrivateEndpointSubnet"
  resource_group_name                            = azurerm_resource_group.shared.name
  virtual_network_name                           = azurerm_virtual_network.hub.name
  address_prefixes                               = ["10.40.3.0/24"]
  private_endpoint_network_policies              = "Enabled" 
}

# Egress rules
resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "egress-rules"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 100

  application_rule_collection {
    name     = "allow-https"
    priority = 100
    action   = "Allow"

    rule {
      name             = "https-http-outbound"
      source_addresses = ["*"]

      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }


      destination_fqdns = [
	"*.docker.com", 
	"*.ubuntu.com",       
	"*.google.com",
	"*.azure.com",
        "*.microsoft.com",
	"*.windows.net",
        "mcr.microsoft.com",
        "login.microsoftonline.com",
	"secure.aadcdn.microsoftonline-p.com",
	"oss.sonatype.org"
      ]
    }
  }
}

# ACR
resource "azurerm_container_registry" "acr" {
  name                          = "jamacrs20260224"
  resource_group_name           = azurerm_resource_group.shared.name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  zone_redundancy_enabled       = true
  public_network_access_enabled = true  # Enables Selected networks mode
  tags                          = var.tags

  network_rule_set {
    default_action = "Deny"
    ip_rule {
      action   = "Allow"
      ip_range = "104.176.84.255/32"  # Your IP; add to variables.tf if dynamic
    }
  }
}

resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-acr-shared"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  tags = var.tags
}

# Log Analytics
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-ja-shared"
  resource_group_name = azurerm_resource_group.shared.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# Key Vault
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

resource "azurerm_private_dns_zone" "acr_data" {
  name                = "privatelink.centralus.data.azurecr.io"  # Adjust region if not centralus
  resource_group_name = azurerm_resource_group.shared.name
  tags                = var.tags
}

# DNS links to HUB only
resource "azurerm_private_dns_zone_virtual_network_link" "acr_hub" {
  name                  = "link-hub-to-acr"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_data_hub" {
  name                  = "link-hub-to-acr-data"
  resource_group_name   = azurerm_resource_group.shared.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_data.name
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

# GitHub OIDC
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

# Front Door + WAF
resource "azurerm_cdn_frontdoor_profile" "ja" {
  name                = "fd-ja-mma"
  resource_group_name = azurerm_resource_group.shared.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "ja" {
  name                     = "ep-ja-mma"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.ja.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_firewall_policy" "ja" {
  name                = "jammawafpolicy"
  resource_group_name = azurerm_resource_group.shared.name
  sku_name            = azurerm_cdn_frontdoor_profile.ja.sku_name
  mode                = "Prevention"
  enabled             = true
  tags                = var.tags

  custom_rule {
    name     = "BlockBadBots"
    enabled  = true
    priority = 1
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RequestHeader"
      operator           = "Contains"
      negation_condition = false
      match_values       = ["bot", "crawler", "spider"]
      transforms         = ["Lowercase"]
      selector           = "User-Agent"
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "ja" {
  name                     = "secpol-ja-mma"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.ja.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.ja.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.ja.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}


# Grants AcrPull to the GitHub CI identity so Container Apps in spoke envs can pull images

resource "azurerm_role_assignment" "container_apps_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}