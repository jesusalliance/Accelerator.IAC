resource "azurerm_resource_group" "env" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

# Spoke VNet
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-ja-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "public" {
  count                = var.az_count
  name                 = "snet-public-az${count.index + 1}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 7, count.index)]
}

resource "azurerm_subnet" "private_app" {
  name                 = "snet-private-app"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, var.az_count)]
  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 11, 16)]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-private-management"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 11, 17)]
}

# Peering
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.environment}-to-hub"
  resource_group_name          = azurerm_resource_group.env.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Route Table - FIXED
resource "azurerm_route_table" "spoke_rt" {
  name                          = "rt-ja-mma-${var.environment}"
  resource_group_name           = azurerm_resource_group.env.name
  location                      = var.location
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name           = "default-to-internet-via-nat"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "app_rt_assoc" {
  subnet_id      = azurerm_subnet.private_app.id
  route_table_id = azurerm_route_table.spoke_rt.id
}

# Container Apps Environment
resource "azurerm_container_app_environment" "cae" {
  name                       = "cae-ja-mma-${var.environment}"
  resource_group_name        = azurerm_resource_group.env.name
  location                   = var.location
  infrastructure_subnet_id   = azurerm_subnet.private_app.id
  log_analytics_workspace_id = var.log_analytics_id
  zone_redundancy_enabled    = var.zone_redundancy_enabled
  tags                       = var.tags
}

# Example Frontend Container App
resource "azurerm_container_app" "frontend" {
  name                         = "frontend-${var.environment}"
  resource_group_name          = azurerm_resource_group.env.name
  container_app_environment_id = azurerm_container_app_environment.cae.id
  revision_mode                = "Multiple"

  template {
    container {
      name   = "frontend"
      image  = "${var.acr_login_server}/frontend:latest"
      cpu    = "0.5"
      memory = "1Gi"
    }
    min_replicas = var.replica_min
    max_replicas = var.replica_max
  }

  identity { type = "SystemAssigned" }

  tags = var.tags
}

# Cosmos DB
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmos-ja-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  offer_type          = "Standard"
  kind                = "MongoDB"

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = var.cosmos_zone_redundant
  }

  consistency_policy {
    consistency_level = "Session"
  }

  backup {
    type                = "Continuous"
    retention_in_hours  = var.backup_retention_hours
  }

  capabilities {
    name = "EnableMongo"
  }

  tags = var.tags
}