# modules/environment/main.tf

resource "azurerm_resource_group" "env" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

# Spoke VNet
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-ja-mma-${var.environment}"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name
  tags                = var.tags
}

# Subnets (sliced as /24 from /21)
locals {
  public_subnet_cidrs   = [for i in range(var.az_count) : cidrsubnet(var.vnet_cidr, 11, i)]
  private_app_cidr      = cidrsubnet(var.vnet_cidr, 11, var.az_count)
  db_cidr               = cidrsubnet(var.vnet_cidr, 11, var.az_count + 1)
  management_cidr       = cidrsubnet(var.vnet_cidr, 11, var.az_count + 2)
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
  count                = var.az_count > 1 ? 1 : 0  # optional in single-AZ
  name                 = "snet-management-${var.environment}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.management_cidr]
}

# Route Table with UDR to Firewall (applied to private subnets)
resource "azurerm_route_table" "private_rt" {
  name                          = "rt-private-${var.environment}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.env.name
  disable_bgp_route_propagation = false

  route {
    name                   = "egress-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub_firewall_private_ip
  }

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "private_app_rt_assoc" {
  subnet_id      = azurerm_subnet.private_app.id
  route_table_id = azurerm_route_table.private_rt.id
}

resource "azurerm_subnet_route_table_association" "db_rt_assoc" {
  subnet_id      = azurerm_subnet.db.id
  route_table_id = azurerm_route_table.private_rt.id
}

# NSGs (basic rules from design)
resource "azurerm_network_security_group" "public_nsg" {
  name                = "nsg-public-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name

  security_rule {
    name                       = "Allow-HTTP-HTTPS-In"
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
    name                       = "Allow-From-Public"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefixes    = local.public_subnet_cidrs  # from public subnets
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSGs
resource "azurerm_subnet_network_security_group_association" "public_nsg_assoc" {
  count                     = var.az_count
  subnet_id                 = azurerm_subnet.public[count.index].id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "private_app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.private_app.id
  network_security_group_id = azurerm_network_security_group.private_app_nsg.id
}

# Private DNS Zone links (to shared zones)
resource "azurerm_private_dns_zone_virtual_network_link" "acr_spoke_link" {
  name                  = "link-${var.environment}-to-acr"
  resource_group_name   = azurerm_resource_group.env.name  # or shared RG if preferred
  private_dns_zone_name = "privatelink.azurecr.io"         # adjust if name differs
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_spoke_link" {
  name                  = "link-${var.environment}-to-cosmos"
  resource_group_name   = azurerm_resource_group.env.name
  private_dns_zone_name = "privatelink.mongo.cosmos.azure.com"
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

# Cosmos DB (MongoDB API)
resource "azurerm_cosmosdb_account" "cosmos" {
  name                              = "cosmos-mma-${var.environment}"
  location                          = var.location
  resource_group_name               = azurerm_resource_group.env.name
  offer_type                        = "Standard"
  kind                              = "MongoDB"
  enable_multiple_write_locations   = false
  enable_automatic_failover         = false
  public_network_access_enabled     = false

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

# Container App Environment
resource "azurerm_container_app_environment" "cae" {
  name                           = "cae-mma-${var.environment}"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.env.name
  infrastructure_subnet_id       = azurerm_subnet.private_app.id
  internal_load_balancer_enabled = (var.ingress_type == "front_door")  # internal for future private link
  log_analytics_workspace_id     = var.log_analytics_id
  tags                           = var.tags
}

# Example Frontend Container App (repeat pattern for Backend)
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

    ingress {
      external_enabled = true   # public for now; change to false + Private Link for strict private
      target_port      = 8080   # adjust to your app port
      traffic_weight {
        percentage = 100
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  registry {
    server               = var.acr_login_server
    identity             = "System"
  }

  tags = var.tags
}

# Conditional Application Gateway (for DEV or when ingress_type = "app_gateway")
resource "azurerm_application_gateway" "appgw" {
  count = var.ingress_type == "app_gateway" ? 1 : 0

  name                = "appgw-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location

  sku {
    name     = var.appgw_sku
    tier     = replace(var.appgw_sku, "_v2", "")
    capacity = null  # use autoscale
  }

  autoscale_configuration {
    min_capacity = var.appgw_capacity
    max_capacity = var.appgw_max_capacity
  }

  gateway_ip_configuration {
    name      = "gw-ip-config"
    subnet_id = azurerm_subnet.public[0].id  # use first public subnet
  }

  # Add frontend_port, frontend_ip, http_listener, backend_address_pool (to ACA FQDN), routing_rule blocks...
  # Example minimal placeholder – expand as needed

  tags = var.tags
}

# Outputs for root or debugging
output "rg_name" {
  value = azurerm_resource_group.env.name
}

output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.cae.id
}