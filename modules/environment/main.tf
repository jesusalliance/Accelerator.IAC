# modules/environment/main.tf - FINAL VERSION (subnet fix to /24 + DNS fix + GitHub CI role)

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
   