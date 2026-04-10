# =============================================================================
# Terraform Azure Infrastructure
# Autor: Hiramatsu, María Jose
# Fecha: Abril 2026
# Descripción: Infraestructura con Load Balancer + VMs + Monitoring
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
}


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

provider "azurerm" {
  features {}
}

#agrego azapi para que azure pueda escribir en Custom-NginxLogs_CL
provider "azapi" {}

resource "azurerm_resource_group" "rg" {
  name = var.resource_group_name
  location = var.location
}

#networinking = vnet --> subnet
module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  vnet_name = "vnet-demo"
  vnet_address_space = ["10.0.0.0/16"]

  subnet_name = "subnet-demo"
  subnet_address_prefix = ["10.0.1.0/24"]
}

#2 virtual machines
module "virtualmachines" {
  source = "./modules/virtualmachines"

  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  subnet_id = module.networking.subnet_id

  ssh_public_key = file("/home/user_pes/.ssh/id_ed25519.pub")

  user_data = <<-EOF
    #!/bin/bash
    sudo su
    apt-get -y update
    apt-get -y install nginx
    echo "<h1>Hola Mundo desde $(hostname)</h1>" > /var/www/html/index.html
    EOF

  log_analytics_workspace_id = module.monitoring.workspace_id
}

#loadbalancer
module "loadbalancer" {
  source = "./modules/loadbalancer"

  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  nic_ids = [
    module.virtualmachines.nic_id_1,
    module.virtualmachines.nic_id_2
  ]
}

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location

  lb_id = module.loadbalancer.lb_id
  nsg_id = module.virtualmachines.nsg_id
}

