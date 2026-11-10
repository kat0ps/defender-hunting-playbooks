# Outputs other modules need: the Sentinel module needs the workspace ID; the lab VM (later)
# needs the resource group and location.

output "resource_group_name" {
  description = "Name of the lab resource group."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region of the resource group."
  value       = azurerm_resource_group.this.location
}

output "workspace_id" {
  description = "Full Azure resource ID of the Log Analytics workspace (used by Sentinel)."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_customer_id" {
  description = "The workspace's GUID (called 'Workspace ID' in the portal), used by agents and the Logs API."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
