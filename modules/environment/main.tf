# modules/environment/main.tf - FINAL VERSION (subnet fix to /24 + DNS fix + GitHub CI role + vnet_id output)

resource "azurerm_resource_group" "env" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-ja-mma-${var.environment}"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name
  tags                = var.tags
}

locals {
  # FIXED: subnet allocation EXACTLY matches PDF v3.0 tables (section 4.0)
  # DEV/UAT (az_count=1): public .0/24, private-app .1/24, DB .2/24
  # PROD (az_count=2): Public AZ1 .0/24, Public AZ2 .4/24 (PDF example), private-app .1/24, DB .2/24, mgmt .3/24
  public_subnet_cidrs = var.environment == "prod" ? [
    cidrsubnet(var.vnet_cidr, 3, 0), # AZ1
    cidrsubnet(var.vnet_cidr, 3, 4)  # AZ2 per design PDF
  ] : [for i in range(var.az_count) : cidrsubnet(var.vnet_cidr, 3, i)]
  private_app_cidr = cidrsubnet(var.vnet_cidr, 3, var.environment == "prod" ? 1 : var.az_count)
  db_cidr          = cidrsubnet(var.vnet_cidr, 3, var.environment == "prod" ? 2 : var.az_count + 1)
  mgmt_cidr        = cidrsubnet(var.vnet_cidr, 3, var.environment == "prod" ? 3 : var.az_count + 2)
}

resource "azurerm_subnet" "public" {
  count                = var.az_count
  name                 = "snet-public-${var.environment}${count.index == 0 ? "" : "-az${count.index + 1}"}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.public_subnet_cidrs[count.index]]
}

resource "azurerm_subnet" "private_app" {
  name                 = "snet-private-app-${var.environment}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.private_app_cidr]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db-${var.environment}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.db_cidr]
}

resource "azurerm_subnet" "management" {
  count                = var.az_count > 1 ? 1 : 0
  name                 = "snet-management-${var.environment}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.mgmt_cidr]
}

resource "azurerm_route_table" "private_rt" {
  name                = "rt-private-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name

  route {
    name                   = "egress-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub_firewall_private_ip
  }
  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "private_app_assoc" {
  subnet_id      = azurerm_subnet.private_app.id
  route_table_id = azurerm_route_table.private_rt.id
}

resource "azurerm_subnet_route_table_association" "db_assoc" {
  subnet_id      = azurerm_subnet.db.id
  route_table_id = azurerm_route_table.private_rt.id
}

resource "azurerm_subnet_route_table_association" "mgmt_assoc" {
  count          = var.az_count > 1 ? 1 : 0
  subnet_id      = azurerm_subnet.management[0].id
  route_table_id = azurerm_route_table.private_rt.id
}

resource "azurerm_network_security_group" "public_nsg" {
  name                = "nsg-public-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name

  security_rule {
    name                       = "AllowHTTPHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  tags = var.tags
}

resource "azurerm_network_security_group" "private_app_nsg" {
  name                = "nsg-private-app-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name

  security_rule {
    name                       = "AllowFromPublicSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefixes    = local.public_subnet_cidrs
    destination_address_prefix = "*"
  }
  tags = var.tags
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "nsg-db-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name

  security_rule {
    name                       = "AllowFromPrivateApp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443"]
    source_address_prefix      = local.private_app_cidr
    destination_address_prefix = "*"
  }
  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "public_assoc" {
  count                     = var.az_count
  subnet_id                 = azurerm_subnet.public[count.index].id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "private_app_assoc" {
  subnet_id                 = azurerm_subnet.private_app.id
  network_security_group_id = azurerm_network_security_group.private_app_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db_assoc" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

# DNS links (now works with shared_rg_name passed)
resource "azurerm_private_dns_zone_virtual_network_link" "acr_link" {
  name                  = "link-${var.environment}-acr"
  resource_group_name   = var.shared_rg_name
  private_dns_zone_name = "privatelink.azurecr.io"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_link" {
  name                  = "link-${var.environment}-cosmos-mongo"
  resource_group_name   = var.shared_rg_name
  private_dns_zone_name = "privatelink.mongo.cosmos.azure.com"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

resource "azurerm_cosmosdb_account" "cosmos" {
  name                          = "cosmos-ja-mma-${var.environment}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.env.name
  offer_type                    = "Standard"
  kind                          = "MongoDB"
  public_network_access_enabled = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = var.cosmos_zone_redundant
  }

  backup {
    type                = "Periodic"
    interval_in_minutes = 240
    retention_in_hours  = var.backup_retention_hours
    storage_redundancy  = "Geo"
  }

  tags = var.tags
}

resource "azurerm_container_app_environment" "cae" {
  name                           = "cae-ja-mma-${var.environment}"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.env.name
  infrastructure_subnet_id       = azurerm_subnet.private_app.id
  internal_load_balancer_enabled = (var.ingress_type == "front_door")
  log_analytics_workspace_id     = var.log_analytics_id
  tags                           = var.tags
}

resource "azurerm_container_app" "frontend" {
  name                         = "frontend-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.env.name
  revision_mode                = "Single"

  template {
    min_replicas = var.replica_min
    max_replicas = var.replica_max

    container {
      name   = "frontend"
      image  = "${var.acr_login_server}/ja-mma-frontend:latest"
      cpu    = "0.5"
      memory = "1Gi"
    }
  }

  ingress_enabled          = true
  ingress_external_enabled = true
  ingress_target_port      = 8080
  tags                     = var.tags

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = var.acr_login_server
    identity = "System"
  }
}

resource "azurerm_container_app" "backend" {
  name                         = "backend-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.env.name
  revision_mode                = "Single"

  template {
    min_replicas = var.replica_min
    max_replicas = var.replica_max

    container {
      name   = "backend"
      image  = "${var.acr_login_server}/ja-mma-backend:latest"
      cpu    = "0.75"
      memory = "1.5Gi"
    }
  }

  ingress_enabled     = false
  ingress_target_port = 8080
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = var.acr_login_server
    identity = "System"
  }
}

resource "azurerm_application_gateway" "appgw" {
  count = var.ingress_type == "app_gateway" ? 1 : 0

  name                = "appgw-ja-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location

  sku {
    name     = var.appgw_sku
    tier     = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = var.appgw_capacity
    max_capacity = var.appgw_max_capacity
  }

  gateway_ip_configuration {
    name      = "gw-ip-config"
    subnet_id = azurerm_subnet.public[0].id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_pip[0].id
  }

  backend_address_pool {
    name  = "backend-pool"
    fqdns = [azurerm_container_app.frontend.default_hostname]
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "http-settings"
  }

  tags = var.tags
}

resource "azurerm_public_ip" "appgw_pip" {
  count               = var.ingress_type == "app_gateway" ? 1 : 0
  name                = "pip-appgw-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# GitHub CI/CD role for deploying to this environment (design 13.0)
resource "azurerm_role_assignment" "github_container_apps" {
  scope                = azurerm_resource_group.env.id
  role_definition_name = "Contributor"
  principal_id         = var.github_ci_principal_id
}

# Required for root peerings
output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "rg_name" {
  value = azurerm_resource_group.env.name
}