# ... (keep your existing RG, VNet, subnets, route table, peering, CAE, Container Apps – but remove ingress block)

# Remove ingress block from frontend and backend Container Apps
resource "azurerm_container_app" "frontend" {
  # ... keep existing ...
  # REMOVE the entire ingress block
  # ingress {
  #   external_enabled = true
  #   target_port      = 80
  #   transport        = "auto"
  # }
  # ...
}

resource "azurerm_container_app" "backend" {
  # ... same – remove ingress block
}

# Dedicated PE subnet
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

# Update ACR PE to use new subnet
resource "azurerm_private_endpoint" "acr_pe" {
  # ... keep existing ...
  subnet_id = azurerm_subnet.private_endpoints.id
  # ...
}

# Application Gateway
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

# Cosmos and PEs (keep existing, but ensure subnet_id for ACR PE uses snet-pe)