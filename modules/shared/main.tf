data "azurerm_client_config" "current" {}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-ja-hub"
  resource_group_name = var.rg_name
  location            = var.location
  address_space       = ["10.40.0.0/21"]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.40.1.0/26"]
}

resource "azurerm_public_ip" "firewall_pip" {
  name                = "pip-firewall"
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  name                = "fw-ja-hub"
  resource_group_name = var.rg_name
  location            = var.location

  sku_name = "AZFW_VNet"
  sku_tier = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }

  tags = var.tags
}

resource "azurerm_container_registry" "acr" {
  name                = "jamacrs20260224"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false
  public_network_access_enabled = false
  zone_redundancy_enabled = true
  tags                = var.tags
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-ja-shared"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-ja-shared"
  location                    = var.location
  resource_group_name         = var.rg_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Import", "Backup", "Restore", "Recover", "Purge"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Backup", "Restore", "Recover", "Purge"
    ]

    certificate_permissions = [
      "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "ManageContacts", "ManageIssuers", "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers"
    ]
  }

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "github_ci" {
  name                = "id-ja-github-ci"
  resource_group_name = var.rg_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github_ci_credential" {
  name                = "github-ci-credential"
  resource_group_name = var.rg_name
  parent_id           = azurerm_user_assigned_identity.github_ci.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:jesusalliance/Accelerator.IAC:ref:refs/heads/main"
}

resource "azurerm_private_dns_zone" "cosmos_mongo" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = var.rg_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.rg_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_to_cosmos_mongo" {
  name                  = "link-hub-to-cosmos-mongo"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos_mongo.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_to_acr" {
  name                  = "link-hub-to-acr"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}