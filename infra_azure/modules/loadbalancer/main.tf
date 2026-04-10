resource "azurerm_public_ip" "lb_ip" {
  name = "lb-public-ip"
  location = var.location
  resource_group_name = var.resource_group_name
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_lb" "lb" {
  name = "demo-lb"
  location = var.location
  resource_group_name = var.resource_group_name
  sku = "Standard"

  frontend_ip_configuration {
    name = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend" {
  loadbalancer_id = azurerm_lb.lb.id
  name = "backend-pool"
}

#asociar NICs al backend pool
resource "azurerm_network_interface_backend_address_pool_association" "association" {
  count = length(var.nic_ids)

  network_interface_id = var.nic_ids[count.index]
  ip_configuration_name = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend.id
}

#health check
resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name = "http-probe"
  protocol = "Http"
  port = 80
  request_path = "/"
}

#regla de balanceo default
resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id = azurerm_lb.lb.id
  name = "http-rule"
  protocol = "Tcp"
  frontend_port = 80
  backend_port = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.backend.id ]
  probe_id = azurerm_lb_probe.http_probe.id
  load_distribution = "Default"
}