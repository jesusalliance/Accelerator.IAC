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

# Subnets – adjusted for multi-AZ in PROD (count-based public subnets)
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

# Peering to shared hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.environment}-to-hub"
  resource_group_name          = azurerm_resource_group.env.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Container Apps Environment
resource "azurerm_container_app_environment" "cae" {
  name                         = "cae-ja-mma-${var.environment}"
  resource_group_name          = azurerm_resource_group.env.name
  location                     = var.location
  infrastructure_subnet_id     = azurerm_subnet.private_app.id
  log_analytics_workspace_id   = var.log_analytics_id
  zone_redundancy_enabled      = var.zone_redundancy_enabled  # true for PROD
  tags                         = var.tags
}

# Example Frontend Container App (add backend similarly when ready)
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

    min_replicas = var.replica_min  # e.g. 1
    max_replicas = var.replica_max  # DEV:3, UAT:5, PROD:20
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Cosmos DB Account (MongoDB API)
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmos-ja-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  offer_type          = "Standard"
  kind                = "MongoDB"

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = var.cosmos_zone_redundant  # true for PROD
  }

  consistency_policy {
    consistency_level = "Session"
  }

  backup {
    type = "Continuous"
    tier = var.environment == "prod" ? "Continuous30Days" : "Continuous7Days"  # Matches doc 10.1
  }

  capabilities {
    name = "EnableMongo"
  }

  tags = merge(var.tags, {
    "backup-enabled"  = "true"
    "backup-policy"   = "daily"
    "environment"     = var.environment
    "cost-center"     = "ja-mma-portal"
    "owner"           = "ja-portal-team"
  })
}

# MongoDB Database with Autoscale (fixes the invalid resource error)
resource "azurerm_cosmosdb_mongo_database" "mma_db" {
  name                = "mma-portal-db-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  account_name        = azurerm_cosmosdb_account.cosmos.name

  autoscale_settings {
    max_throughput = var.cosmos_max_throughput  # e.g. 4000 DEV/UAT, 20000 PROD
  }

  throughput = null  # Must be null with autoscale
}

# Example Collection (add your actual collections; inherits autoscale)
resource "azurerm_cosmosdb_mongo_collection" "portal_data" {
  name                = "portal-data"
  resource_group_name = azurerm_resource_group.env.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_mongo_database.mma_db.name

  shard_key           = "_id"  # Adjust based on your data model
  default_ttl_seconds = "-1"

  index {
    keys   = ["_id"]
    unique = true
  }
}

# Private Endpoint for Cosmos DB
resource "azurerm_private_endpoint" "cosmos_pe" {
  name                = "pe-cosmos-ja-mma-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name
  subnet_id           = azurerm_subnet.private_endpoints.id

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

  tags = var.tags
}



# Centralized NAT association for private app subnet (preferred over UDR for egress)
resource "azurerm_subnet_nat_gateway_association" "private_app_nat" {
  subnet_id      = azurerm_subnet.private_app.id
  nat_gateway_id = var.hub_nat_gateway_id   # ← FIXED: Use existing var (passed from root main.tf)
}

# Optional: Remove or comment out your old route table blocks if NAT association is sufficient
# resource "azurerm_route_table" "spoke_rt" { ... }
# resource "azurerm_subnet_route_table_association" "app_rt_assoc" { ... }