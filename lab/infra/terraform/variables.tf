# variables.tf: the lab's settings. Give them values in terraform.tfvars (copy terraform.tfvars.example;
# the real .tfvars file is git-ignored) or with -var on the command line.

variable "location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "southafricanorth"
}

variable "name_prefix" {
  description = "Short prefix used in resource names, e.g. 'sentinel-lab' -> rg-sentinel-lab, law-sentinel-lab."
  type        = string
  default     = "sentinel-lab"
}

variable "daily_quota_gb" {
  description = "Log Analytics daily ingestion cap in GB (cost safety net). -1 = no cap."
  type        = number
  default     = 1
}

variable "retention_in_days" {
  description = "Workspace data retention in days. Sentinel workspaces include 90 days at no extra cost."
  type        = number
  default     = 90
}

# Start with an empty list: a brand-new workspace has no tables, so no rules can be created yet.
# After each connector starts sending data, add its tables here and run plan again.
# The "missing_tables" output tells you what's still blocking.
variable "available_tables" {
  description = "Tables that already contain data in the workspace. Rules are only deployed when all their requiredTables are listed here."
  type        = list(string)
  default     = []
}

variable "enabled_rules" {
  description = "Sentinel rules to deploy, by YAML file name without .yaml (e.g. [\"legacy-auth-success\"]). null = all rules."
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default = {
    project     = "defender-hunting-playbooks"
    environment = "lab"
    managed_by  = "terraform"
  }
}
