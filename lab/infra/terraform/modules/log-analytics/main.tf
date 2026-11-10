# log-analytics module: the storage layer of the lab.
# Sentinel isn't a separate database. It's a solution that runs on top of a Log Analytics workspace,
# so this workspace is where every log (sign-ins, Office 365, Defender XDR events) ends up and
# where the analytics rules run their KQL.

# A dedicated resource group keeps the lab self-contained: deleting it removes everything.
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.workspace_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  # PerGB2018 = pay per GB ingested. It's the standard SKU for new workspaces and the one Sentinel uses.
  sku               = "PerGB2018"
  retention_in_days = var.retention_in_days
  daily_quota_gb    = var.daily_quota_gb

  tags = var.tags
}
