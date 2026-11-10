# Inputs for the log-analytics module.

variable "resource_group_name" {
  description = "Name of the resource group that holds the lab's monitoring resources."
  type        = string
}

variable "workspace_name" {
  description = "Name of the Log Analytics workspace (4-63 characters: letters, numbers, hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$", var.workspace_name))
    error_message = "workspace_name must be 4-63 characters, letters/numbers/hyphens, and not start or end with a hyphen."
  }
}

variable "location" {
  description = "Azure region for the resource group and workspace."
  type        = string
}

# WHY: the daily cap is the main cost safety net in a pay-per-GB workspace. When ingestion reaches
# the cap, Azure stops collecting billable data until the next day, so a noisy connector can't run up
# a big bill. 1 GB/day is plenty for a one-person lab.
variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. -1 removes the cap (not recommended for a lab)."
  type        = number
  default     = 1

  validation {
    condition     = var.daily_quota_gb == -1 || var.daily_quota_gb > 0
    error_message = "daily_quota_gb must be -1 (no cap) or greater than 0."
  }
}

# WHY 90: a workspace with Sentinel enabled keeps 90 days of data at no extra retention cost,
# so going lower saves nothing and loses evidence.
variable "retention_in_days" {
  description = "How long the workspace keeps data (30-730 days)."
  type        = number
  default     = 90

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "tags" {
  description = "Tags applied to every resource (helps with cost reports and cleanup)."
  type        = map(string)
  default     = {}
}
