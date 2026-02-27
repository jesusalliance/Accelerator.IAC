# =============================================
# modules/environment/main.tf
# Environment-specific resources (DEV/UAT/PROD)
# Updated for 3.0 design: DB subnet, Backend container, Route Table + UDR to Firewall
# Region: Central US
# Fixes: Removed invalid 'tags' from subnets (not supported), kept all other corrections
# =============================================

resource "azurerm_resource_group" "env" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

# Spoke VNet (tags here are inherited by subnets)
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-ja-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

# Public Subnets (multi-AZ in PROD) - NO tags argument
resource "azurerm_subnet" "public" {
  count                = var.az_count
  name                 = "snet-public-az${count.index + 1}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 3, count.index)]
}

# Private-App Subnet - NO tags argument
resource "azurerm_subnet" "private_app" {
  name                 = "snet-private-app"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 3, var.az_count)]

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# DB Subnet - NO tags argument
resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 3, var.az_count + 1)]
}

# Management Subnet (optional) - NO tags argument
resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 3, var.az_count + 2)]
}

# Route Table + UDR to Firewall
resource "azurerm_route_table" "spoke_rt" {
  name                = "rt-${var.environment}-egress"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location

  route {
    name                   = "to-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub_firewall_private_ip
  }

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "private_app" {
  subnet_id      = azurerm_subnet.private_app.id
  route_table_id = azurerm_route_table.spoke_rt.id
}

resource "azurerm_subnet_route_table_association" "db" {
  subnet_id      = azurerm_subnet.db.id
  route_table_id = azurerm_route_table.spoke_rt.id
}

# Peering to hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.environment}-to-hub"
  resource_group_name          = azurerm_resource_group.env.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Container App Environment
resource "azurerm_container_app_environment" "cae" {
  name                       = "cae-ja-mma-${var.environment}"
  resource_group_name        = azurerm_resource_group.env.name
  location                   = var.location
  infrastructure_subnet_id   = azurerm_subnet.private_app.id
  log_analytics_workspace_id = var.log_analytics_id
  zone_redundancy_enabled    = var.zone_redundancy_enabled
  tags                       = var.tags
}

# Frontend Container App
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

  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}

# Backend Container App
resource "azurerm_container_app" "backend" {
  name                         = "backend-${var.environment}"
  resource_group_name          = azurerm_resource_group.env.name
  container_app_environment_id = azurerm_container_app_environment.cae.id
  revision_mode                = "Multiple"

  template {
    container {
      name   = "backend"
      image  = "${var.acr_login_server}/backend:latest"
      cpu    = "1.0"
      memory = "2Gi"
    }
    min_replicas = var.replica_min
    max_replicas = var.replica_max
  }

  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}

# Cosmos DB Account (correct capability)
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmos-ja-mma-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  backup {
    type                = "Periodic"
    interval_in_minutes = 1440
    retention_in_hours  = var.backup_retention_hours
  }

  capabilities {
    name = "EnableMongo"  # Correct and validated value
  }

  tags = var.tags
}

# Private Endpoint for Cosmos DB
resource "azurerm_private_endpoint" "cosmos_pe" {
  name                = "pe-cosmos-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  subnet_id           = azurerm_subnet.db.id

  private_service_connection {
    name                           = "psc-cosmos-${var.environment}"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.shared_cosmos_dns_zone_id]
  }
}

# Private Endpoint for ACR
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-acr-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  subnet_id           = azurerm_subnet.db.id

  private_service_connection {
    name                           = "psc-acr-${var.environment}"
    private_connection_resource_id = var.acr_id  # Pass from shared if needed
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.shared_acr_dns_zone_id]
  }
}