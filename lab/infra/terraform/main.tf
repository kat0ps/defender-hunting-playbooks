# main.tf: the root module. It wires the reusable modules together; the modules contain the resources.
# Order: log-analytics (workspace) -> sentinel (onboarding + analytics rules).
# The lab-vm and cost-guardrails modules will be added here by the scaffold step (Prompt 1).

locals {
  resource_group_name = "rg-${var.name_prefix}"
  workspace_name      = "law-${var.name_prefix}"
}

# Resource group + Log Analytics workspace with a daily cap.
module "log_analytics" {
  source = "./modules/log-analytics"

  resource_group_name = local.resource_group_name
  workspace_name      = local.workspace_name
  location            = var.location
  daily_quota_gb      = var.daily_quota_gb
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

# Sentinel on top of that workspace, plus the analytics rules from detections/sentinel/*.yaml.
module "sentinel" {
  source = "./modules/sentinel"

  workspace_id = module.log_analytics.workspace_id

  # path.root is this folder (lab/infra/terraform), so three levels up is the repo root.
  rules_path       = "${path.root}/../../../detections/sentinel"
  available_tables = var.available_tables
  enabled_rules    = var.enabled_rules
}
