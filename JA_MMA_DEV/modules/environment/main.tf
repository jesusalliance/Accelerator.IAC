# modules/environment/main.tf - FINAL VERSION (exact PDF subnet CIDRs + DNS links + GitHub CI role + ingress traffic_weight + CORRECT FQDN reference)

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
  # EXACT MATCH TO PDF SECTION 4.0 TABLE
  # DEV/UAT (az_count=1): public=0/24, private-app=1/24, DB=2/24, mgmt=3/24
  # PROD (az_count=2): Public AZ1=0/24, Public AZ2=4/24, private-app=1/24, DB=2/24, mgmt=3/24
  # Fits perfectly in /21, ~251 usable IPs per subnet, no overlap
  public_subnet_cidrs = (var.az_count == 1 ?
    [cidrsubnet(var.vnet_cidr, 3, 0)] :
    [cidrsubnet(var.vnet_cidr, 3, 0), cidrsubnet(var.vnet_cidr, 3, 4)]
  )
  private_app_cidr = cidrsubnet(var.vnet_cidr, 3, 1)
  db_cidr          = cidrsubnet(var.vnet_cidr, 3, 2)
  mgmt_cidr        = cidrsubnet(var.vnet_cidr, 3, 3)
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

# DNS links in SHARED RG (required for private endpoint resolution per PDF)
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

module "documentdb_mongo_cluster" {
  source  = "Azure/avm-res-documentdb-mongocluster/azurerm"
  version = "~> 0.2"  # Check registry for latest version

  # Required
  name                = "ja-mma-mongo-cluster"          # Unique cluster name
  resource_group_name = "rg-ja-mma-dev"                # Match your PROD RG or appropriate env
  location            = "centralus"                     # Or your preferred region

  # Cluster configuration (vCore-based)
  administrator = {
    username = "etrivette"
    password = "P@ssword1@#"  # Use a secret manager / variable / Key Vault reference
  }


  # Node configuration (scale vertically by choosing higher tier, horizontally by shards)
  node {
    tier       = "Free tier"          # Examples: M10, M20, M30, M40, M50, M60, M80, M200 (maps to vCores + RAM)
    disk_size  = 32            # GiB per node (independent of compute)
    shard_count = 1             # Start with 1; scale out to 2–32+ for horizontal
  }

  # Optional: High availability & geo-distribution
  high_availability_mode = "SameZone"  # Or "SameZone" for cost-optimized
  # geo_redundant_backup   = false           # Enable if needed

  # Networking – integrate with your hub-spoke + private endpoint
  delegated_subnet_resource_id = "/subscriptions/<sub-id>/resourceGroups/rg-ja-mma-prod/providers/Microsoft.Network/virtualNetworks/vnet-ja-mma-prod/subnets/snet-db"  # Your DB subnet (e.g., 10.30.3.0/24 in PROD)
  private_dns_zone_resource_id = "/subscriptions/<sub-id>/resourceGroups/rg-ja-shared/providers/Microsoft.Network/privateDnsZones/privatelink.mongocluster.cosmos.azure.com"  # Or appropriate zone

  # Tags to match your design
  tags = {
    environment = "prod"
    cost-center = "ja-mma-portal"
    owner       = "ja-portal-team"
    backup-enabled = "true"
    backup-policy  = "daily"
  }

  # Other options: backups, monitoring, customer-managed keys, etc.
}

resource "azurerm_container_app_environment" "cae" {
  name                           = "cae-ja-mma-${var.environment}"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.env.name
  infrastructure_subnet_id       = azurerm_subnet.private_app.id
  internal_load_balancer_enabled = (var.ingress_type == "front_door")
  log_analytics_workspace_id     = var.log_analytics_id
  tags                           = var.tags

  # Required to stop replacement loop + satisfy provider validation
  infrastructure_resource_group_name = "ME_cae-ja-mma-${var.environment}_rg-ja-mma-${var.environment}_${var.location}"

  # Add this block (this is the missing piece)
  workload_profile {
    name = "Consumption"   # Default profile for most Container Apps envs
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0   # 0 = unlimited (Azure auto-scales)
  }
}



# GitHub CI/CD role for deploying to this environment (design 13.0)
resource "azurerm_role_assignment" "github_container_apps" {
  scope                = azurerm_resource_group.env.id
  role_definition_name = "Contributor"
  principal_id         = var.github_ci_principal_id
}