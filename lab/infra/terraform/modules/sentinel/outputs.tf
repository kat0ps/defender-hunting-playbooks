# Outputs from the Sentinel module. The root module passes them through, so after `terraform plan`
# or `apply` you can see what was deployed, what was held back, and which connector to enable next.

output "sentinel_onboarding_id" {
  description = "Resource ID of the Sentinel onboarding (proves Sentinel is enabled on the workspace)."
  value       = azurerm_sentinel_log_analytics_workspace_onboarding.this.id
}

output "deployed_rules" {
  description = "Rule key => display name for every analytics rule Terraform manages."
  value       = { for key, rule in azurerm_sentinel_alert_rule_scheduled.this : key => rule.display_name }
}

output "skipped_rules" {
  description = "Rules you enabled that were NOT deployed because some of their tables have no data yet (rule key => missing tables)."
  value       = local.skipped_rules
}

output "missing_tables" {
  description = "Every table blocking at least one enabled rule. Enable the connector for these next (see lab/docs/data-connectors.md)."
  value       = sort(distinct(flatten(values(local.skipped_rules))))
}

output "not_enabled_rules" {
  description = "Rules in rules_path that you left out of enabled_rules."
  value       = sort(tolist(setsubtract(toset(keys(local.rules)), toset(keys(local.selected_rules)))))
}
