# outputs.tf: values printed after plan/apply (and available via `terraform output`).
# The rule outputs are the ones to watch while you connect data sources.

output "resource_group_name" {
  description = "Lab resource group."
  value       = module.log_analytics.resource_group_name
}

output "workspace_name" {
  description = "Log Analytics / Sentinel workspace name."
  value       = module.log_analytics.workspace_name
}

output "deployed_rules" {
  description = "Analytics rules Terraform has deployed (rule key => display name)."
  value       = module.sentinel.deployed_rules
}

output "skipped_rules" {
  description = "Enabled rules held back because their tables have no data yet (rule key => missing tables)."
  value       = module.sentinel.skipped_rules
}

output "missing_tables" {
  description = "Tables to connect next. See lab/docs/data-connectors.md for the connector that provides each one."
  value       = module.sentinel.missing_tables
}

output "not_enabled_rules" {
  description = "Rules not in enabled_rules."
  value       = module.sentinel.not_enabled_rules
}
