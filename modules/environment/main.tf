# =============================================
# modules/environment/main.tf
# Environment-specific resources (DEV/UAT/PROD)
# NOW INCLUDES APPLICATION GATEWAY per v3.0 design
# =============================================

resource "azurerm_resource_group" "env" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-ja-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "public" {
  count                = var.az_count
  name                 = "snet-public-az${count.index + 1}"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 3, count.index)]
}

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

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 3, var.az_count + 1)]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.env.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 3, var.az_count + 3)]

  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet_route_table_association" "pe_rt" {
  subnet_id      = azurerm_subnet.private_endpoints.id
  route_table_id = azurerm_route_table.spoke_rt.id
}

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

resource "azurerm_subnet_route_table_association" "private_app_rt" {
  subnet_id      = azurerm_subnet.private_app.id
  route_table_id = azurerm_route_table.spoke_rt.id
}

resource "azurerm_subnet_route_table_association" "db_rt" {
  subnet_id      = azurerm_subnet.db.id
  route_table_id = azurerm_route_table.spoke_rt.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.environment}-to-hub"
  resource_group_name          = azurerm_resource_group.env.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_container_app_environment" "cae" {
  name                       = "cae-ja-mma-${var.environment}"
  resource_group_name        = azurerm_resource_group.env.name
  location                   = var.location
  infrastructure_subnet_id   = azurerm_subnet.private_app.id
  log_analytics_workspace_id = var.log_analytics_id
  tags                       = var.tags
}

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

resource "azurerm_public_ip" "appgw_pip" {
  count = var.deploy_app_gateway ? 1 : 0

  name                = "pip-appgw-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.appgw_domain_label != null ? var.appgw_domain_label : "ja-mma-${var.environment}"
  zones               = var.az_count > 1 ? ["1", "2", "3"] : null

  tags = var.tags
}

resource "azurerm_application_gateway" "appgw" {
  count = var.deploy_app_gateway ? 1 : 0

  name                = "appgw-ja-mma-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = var.location

  sku {
    name     = var.appgw_sku
    tier     = var.appgw_sku
    capacity = var.appgw_capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.public[0].id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.appgw_pip[0].id
  }

  backend_address_pool {
    name  = "frontend-pool"
    fqdns = ["${azurerm_container_app.frontend.name}.${azurerm_container_app_environment.cae.name}.internal.azurecontainerapps.io"]
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
  }

  backend_http_settings {
    name                                      = "http-settings"
    cookie_based_affinity                     = "Disabled"
    port                                      = 80
    protocol                                  = "Http"
    request_timeout                           = 60
    probe_name                                = "health-probe"
    pick_host_name_from_backend_http_settings = true
  }

  request_routing_rule {
    name                       = "https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "frontend-pool"
    backend_http_settings_name = "http-settings"
  }

  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    port                = 80
  }

  tags = var.tags
}

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

  tags = var.tags
}

resource "azurerm_private_endpoint" "cosmos_pe" {
  name                = "pe-cosmos-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name
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

resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-acr-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.env.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-acr-${var.environment}"
    private_connection_resource_id = var.acr_id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.shared_acr_dns_zone_id]
  }
}