# ... (keep all your existing resources: VNet, Firewall, ACR, Log Analytics, Key Vault, Private DNS)

# Key Vault – remove invalid rbac_authorization_enabled
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

# Federated Identity Credential – add required resource_group_name
resource "azurerm_federated_identity_credential" "github_ci_credential" {
  name                = "github-ci-credential"
  resource_group_name = var.rg_name  # ← ADDED HERE
  parent_id           = azurerm_user_assigned_identity.github_ci.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:jesusalliance/Accelerator.IAC:ref:refs/heads/main"
}