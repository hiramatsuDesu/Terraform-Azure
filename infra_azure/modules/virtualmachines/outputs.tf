output "nic_id_1" {
  value = azurerm_network_interface.nic-1.id
}

output "nic_id_2" {
  value = azurerm_network_interface.nic-2.id
}

output "nsg_id" {
  value = azurerm_network_security_group.nsg.id
}
