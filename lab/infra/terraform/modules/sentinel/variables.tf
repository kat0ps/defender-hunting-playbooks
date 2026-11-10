# Inputs for the Sentinel module. The root module (lab/infra/terraform/main.tf) sets these.

variable "workspace_id" {
  description = "Resource ID of the Log Analytics workspace to turn into a Sentinel workspace."
  type        = string
}

variable "rules_path" {
  description = "Folder containing the Sentinel rule YAML files (detections/sentinel). Every *.yaml file in it is one analytics rule."
  type        = string
}

# WHY this exists: Sentinel validates the query when a rule is created and rejects it if any table
# it reads doesn't exist in the workspace yet. A table only exists after its connector has sent data.
# So a fresh workspace can't accept any of these rules. This list is the gate: add a table here
# once you can see rows for it in Sentinel → Logs.
variable "available_tables" {
  description = "Tables that already have data in the workspace. A rule is only deployed when every table in its requiredTables is in this list."
  type        = list(string)
  default     = []
}

# WHY this exists: while learning, deploy one rule, check it in the portal, then add the next.
# null (the default) means "every rule in rules_path".
variable "enabled_rules" {
  description = "Rule keys (YAML file names without .yaml) to deploy, e.g. [\"legacy-auth-success\"]. null = all rules."
  type        = list(string)
  default     = null
}
