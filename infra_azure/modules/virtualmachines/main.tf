terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.1.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }
}

resource "azurerm_network_security_group" "nsg" {
  name = "vm-nsg"
  location = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name = "allow-ssh"
    priority = 1000
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "allow-http"
    priority = 1001
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range= "*"
    destination_port_range = "80"
    source_address_prefix= "*"
    destination_address_prefix = "*"
  }
}

# NIC 1
resource "azurerm_network_interface" "nic-1" {
  name= "vm-nic-1"
  location = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name = "internal"
    subnet_id= var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# NIC 2
resource "azurerm_network_interface" "nic-2" {
  name= "vm-nic-2"
  location= var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name= "internal"
    subnet_id= var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# NSG Associations
resource "azurerm_network_interface_security_group_association" "nsg_assoc1" {
  network_interface_id      = azurerm_network_interface.nic-1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc2" {
  network_interface_id      = azurerm_network_interface.nic-2.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


# VIRTUAL MACHINES
resource "azurerm_linux_virtual_machine" "vm1" {
  name= "vm-demo-1"
  resource_group_name = var.resource_group_name
  location= var.location
  size= "Standard_D2s_v3"
  admin_username= "azureuser"

  network_interface_ids = [azurerm_network_interface.nic-1.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching= "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer= "0001-com-ubuntu-server-jammy"
    sku= "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(var.user_data)

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name= "vm-demo-2"
  resource_group_name = var.resource_group_name
  location= var.location
  size= "Standard_D2s_v3"
  admin_username= "azureuser"

  network_interface_ids = [azurerm_network_interface.nic-2.id]

  admin_ssh_key {
    username = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching= "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer= "0001-com-ubuntu-server-jammy"
    sku= "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(var.user_data)

  identity {
    type = "SystemAssigned"
  }
}

# Azure Monitor Agent
resource "azurerm_virtual_machine_extension" "ama-vm1" {
  name= "AzureMonitorLinuxAgent"
  virtual_machine_id= azurerm_linux_virtual_machine.vm1.id
  publisher= "Microsoft.Azure.Monitor"
  type= "AzureMonitorLinuxAgent"
  type_handler_version= "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "ama-vm2" {
  name= "AzureMonitorLinuxAgent"
  virtual_machine_id= azurerm_linux_virtual_machine.vm2.id
  publisher= "Microsoft.Azure.Monitor"
  type= "AzureMonitorLinuxAgent"
  type_handler_version= "1.0"
  auto_upgrade_minor_version = true
}


# NGINX LOGS COLLECTION (DCR + Tabla)
# Data Collection Endpoint
resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name= "dce-vm-logs"
  location= var.location
  resource_group_name= var.resource_group_name
  kind= "Linux"
  public_network_access_enabled = true
}

# Tabla personalizada NginxLogs_CL usando azapi (la forma correcta)
# Tabla personalizada NginxLogs_CL usando azapi (versión compatible con azapi v2.x)
resource "azapi_resource" "nginx_logs_table" {
  type= "Microsoft.OperationalInsights/workspaces/tables@2023-09-01"
  name= "NginxLogs_CL"
  parent_id = var.log_analytics_workspace_id

  body = {
    properties = {
      schema = {
        name = "NginxLogs_CL"
        columns = [
          { name = "TimeGenerated", type = "datetime" },
          { name = "RawData",type = "string" },
          { name = "Computer",type = "string" },
          { name = "FilePath",type = "string" },
          { name = "NGINX_LogType", type = "string" }
        ]
      }
      plan = "Analytics"
    }
  }
}




# Data Collection Rule para logs de nginx
resource "azurerm_monitor_data_collection_rule" "dcr" {
  name= "vm-logs-dcr"
  location= var.location
  resource_group_name= var.resource_group_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id

  destinations {
    log_analytics {
      name= "logdest"
      workspace_resource_id = var.log_analytics_workspace_id
    }
  }

  data_sources {
    log_file {
      name= "nginx-logs"
      streams= ["Custom-NginxLogs_CL"]
      file_patterns = [
        "/var/log/nginx/access.log",
        "/var/log/nginx/error.log"
      ]
      format = "text"

      settings {
        text {
          record_start_timestamp_format = "ISO 8601"
        }
      }
    }
  }

  data_flow {
    streams= ["Custom-NginxLogs_CL"]
    destinations = ["logdest"]
  }

  depends_on = [azapi_resource.nginx_logs_table]
}

# Asociaciones del DCR a las VMs
resource "azurerm_monitor_data_collection_rule_association" "vm1_assoc" {
  name= "vm1-dcr"
  target_resource_id= azurerm_linux_virtual_machine.vm1.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id

  depends_on = [
    azurerm_virtual_machine_extension.ama-vm1,
    azurerm_monitor_data_collection_endpoint.dce,
    azapi_resource.nginx_logs_table
  ]
}

resource "azurerm_monitor_data_collection_rule_association" "vm2_assoc" {
  name= "vm2-dcr"
  target_resource_id= azurerm_linux_virtual_machine.vm2.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id

  depends_on = [
    azurerm_virtual_machine_extension.ama-vm2,
    azurerm_monitor_data_collection_endpoint.dce,
    azapi_resource.nginx_logs_table
  ]
}

