resource "azurerm_virtual_network" "vnet" {
  name = var.vnet_name
  location = var.location
  resource_group_name = var.resource_group_name

  address_space = var.vnet_address_space
}

resource "azurerm_subnet" "subnet" {
    name = var.subnet_name
    resource_group_name = var.resource_group_name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = var.subnet_address_prefix
}

resource "azurerm_public_ip" "nat_ip" {
  name = "nat-public-ip"
  location = var.location
  resource_group_name = var.resource_group_name
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  name = "nat-gateway"
  location = var.location
  resource_group_name = var.resource_group_name
  sku_name = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  nat_gateway_id = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "nat_assoc" {
  subnet_id = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}