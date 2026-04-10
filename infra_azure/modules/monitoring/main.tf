#desarrollo un modulo especialmente para el loggin de las virtual machines
#y del load balancer como módulo aparte y diferente de estos recursos porque lo
#considero transversal a todos los recursos: las 2 virtual machines y el load balancer

#Log analytics workspace
resource "azurerm_log_analytics_workspace" "law" {
  name = "demo-law"
  location = var.location
  resource_group_name = var.resource_group_name
  sku = "PerGB2018"
  retention_in_days = 30
}

#logs del load balancer
resource "azurerm_monitor_diagnostic_setting" "lb_logs" {
  name = "lb-diagnostics"
  target_resource_id = var.lb_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  
  metric {
    category = "AllMetrics"
  }
}

#logs nsg networkc security group
resource "azurerm_monitor_diagnostic_setting" "nsg_logs" {
  name = "nsg-diagnostics"
  target_resource_id = var.nsg_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}