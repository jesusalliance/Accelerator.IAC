# =============================================
# modules/shared/main.tf
# Shared resources for Jesus Alliance MMA Portal
# Centralized in rg-ja-shared
# =============================================

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

# ACR Premium - CHANGE THIS NAME TO SOMETHING GLOBALLY UNIQUE
resource "azurerm_container_registry" "acr" {
  name                          = "felixjamacrs20260224"  # ← MUST BE UNIQUE – change if error
  resource_group_name           = var.rg_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  zone_redundancy_enabled       = true
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

# Key Vault
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

# Private DNS Zone (example for Cosmos MongoDB)
resource "azurerm_private_dns_zone" "cosmos_mongo" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = var.rg_name
  tags                = var.tags
}

# =============================================
# NEW: GitHub OIDC Federation & Managed Identity (Section 11.1)
# Single user-assigned identity for CI/CD workflows
# =============================================

# User-assigned managed identity for GitHub Actions OIDC
resource "azurerm_user_assigned_identity" "github_ci" {
  name                = "id-ja-github-ci"
  resource_group_name = var.rg_name
  location            = var.location
  tags                = var.tags
}

# Federated credential - links to your GitHub repo/branch
resource "azurerm_federated_identity_credential" "github_ci_credential" {
  name                = "github-ci-federated"
  resource_group_name = var.rg_name
  parent_id           = azurerm_user_assigned_identity.github_ci.id
  audience            = ["api://AzureADTokenExchange"]  # ← FIXED: must be a list
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:FelixCarballo/Accelerator.IAC:ref:refs/heads/main"  # ← CHANGE TO YOUR ACTUAL REPO & BRANCH
  # Examples:
  # repo:your-org/your-repo:ref:refs/heads/main
  # repo:your-org/your-repo:ref:refs/heads/dev
  # repo:your-org/your-repo:pull_request
  # repo:your-org/your-repo:environment:prod
}

# RBAC role assignments - minimal least-privilege

# 1. AcrPush for pushing images to shared ACR
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}

# 2. Azure Container Apps Contributor on all env RGs (deploy revisions)
resource "azurerm_role_assignment" "github_container_dev" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/rg-ja-mma-dev"
  role_definition_name = "Azure Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}

resource "azurerm_role_assignment" "github_container_uat" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/rg-ja-mma-uat"
  role_definition_name = "Azure Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}

resource "azurerm_role_assignment" "github_container_prod" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/rg-ja-mma-prod"
  role_definition_name = "Azure Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}

# 3. Key Vault Secrets User (read secrets during workflow)
resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.github_ci.principal_id
}