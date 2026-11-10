# Sentinel module: switches Microsoft Sentinel on for a Log Analytics workspace and creates one
# scheduled analytics rule per YAML file in var.rules_path ("detections as code").
#
# Flow:  detections/sentinel/*.yaml --fileset+yamldecode--> local.rules
#        --filter by enabled_rules--> local.selected_rules
#        --filter by available_tables--> local.deployable_rules --for_each--> analytics rules

locals {
  # Every YAML file in the rules folder, e.g. ["impossible-travel.yaml", "legacy-auth-success.yaml", ...].
  # fileset() runs at plan time, so adding a YAML file automatically adds a rule.
  rule_files = fileset(var.rules_path, "*.yaml")

  # Map of rule key => decoded YAML. The key is the file name without ".yaml". It becomes the
  # Terraform address (azurerm_sentinel_alert_rule_scheduled.this["legacy-auth-success"]), so renaming
  # a file means Terraform deletes the old rule and creates a new one.
  rules = {
    for f in local.rule_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${var.rules_path}/${f}"))
  }

  # Which rules you asked for. Terraform's || doesn't short-circuit, so null is handled with a
  # conditional here instead of inside the filter below.
  enabled_rule_names = var.enabled_rules == null ? keys(local.rules) : var.enabled_rules

  selected_rules = {
    for key, rule in local.rules : key => rule
    if contains(local.enabled_rule_names, key)
  }

  # For each selected rule, the tables it needs that don't have data yet (empty list = ready).
  missing_tables_by_rule = {
    for key, rule in local.selected_rules :
    key => sort(tolist(setsubtract(toset(rule.requiredTables), toset(var.available_tables))))
  }

  # A rule is deployed only if it's in enabled_rules AND all of its tables exist.
  deployable_rules = {
    for key, rule in local.selected_rules : key => rule
    if length(local.missing_tables_by_rule[key]) == 0
  }

  # Selected rules held back because of missing tables (reported in outputs.tf).
  skipped_rules = {
    for key, missing in local.missing_tables_by_rule : key => missing
    if length(missing) > 0
  }
}

# Turns the workspace into a Sentinel workspace. Analytics rules can only be created after this exists,
# so every rule below references it (that reference also sets the creation order).
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = var.workspace_id
}

# One scheduled analytics rule per deployable YAML file.
resource "azurerm_sentinel_alert_rule_scheduled" "this" {
  for_each = local.deployable_rules

  # The YAML id (a GUID) is the rule's resource name in Azure, so it must never change.
  name                       = each.value.id
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = each.value.name
  description                = trimspace(each.value.description)
  severity                   = each.value.severity
  enabled                    = try(each.value.enabled, true)

  query             = each.value.query
  query_frequency   = each.value.queryFrequency
  query_period      = each.value.queryPeriod
  trigger_operator  = each.value.triggerOperator
  trigger_threshold = each.value.triggerThreshold

  tactics    = each.value.tactics
  techniques = each.value.techniques

  # AlertPerResult: every row the query returns becomes its own alert, with its own entities.
  # (SingleAlert would merge all rows from one run into one alert.)
  event_grouping {
    aggregation_method = "AlertPerResult"
  }

  # Create an incident for every alert and don't group them. In a lab that makes each test easy to
  # find and screenshot. In production you'd usually turn grouping on to reduce noise.
  incident {
    create_incident_enabled = true
    grouping {
      enabled = false
    }
  }

  # One entity_mapping block per entry in the YAML entityMappings list. Each block has 1-3
  # field_mapping blocks (identifier = entity property, column_name = query result column).
  dynamic "entity_mapping" {
    for_each = each.value.entityMappings
    content {
      entity_type = entity_mapping.value.entityType

      dynamic "field_mapping" {
        for_each = entity_mapping.value.fieldMappings
        content {
          identifier  = field_mapping.value.identifier
          column_name = field_mapping.value.columnName
        }
      }
    }
  }
}

# A typo in enabled_rules would otherwise just deploy nothing. This check prints a warning during plan
# when a name doesn't match any YAML file. It doesn't block the run.
check "enabled_rules_exist" {
  assert {
    condition     = length(setsubtract(toset(local.enabled_rule_names), toset(keys(local.rules)))) == 0
    error_message = "enabled_rules contains names with no matching YAML file in rules_path: ${join(", ", sort(tolist(setsubtract(toset(local.enabled_rule_names), toset(keys(local.rules))))))}"
  }
}
