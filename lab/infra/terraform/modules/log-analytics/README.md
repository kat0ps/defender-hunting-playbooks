# log-analytics module

Creates the lab resource group and the Log Analytics workspace that Sentinel runs on. The workspace has a daily ingestion cap so a noisy data source can't run up a large bill.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `resource_group_name` | string | required | Name of the resource group. |
| `workspace_name` | string | required | Name of the workspace (4-63 characters). |
| `location` | string | required | Azure region. |
| `daily_quota_gb` | number | `1` | Daily ingestion cap in GB (`-1` = no cap). |
| `retention_in_days` | number | `90` | Data retention (30-730 days). |
| `tags` | map(string) | `{}` | Tags for every resource. |

## Outputs

| Name | Description |
|---|---|
| `resource_group_name` | Name of the resource group. |
| `location` | Region of the resource group. |
| `workspace_id` | Azure resource ID of the workspace. |
| `workspace_name` | Name of the workspace. |
| `workspace_customer_id` | The workspace GUID shown as "Workspace ID" in the portal. |
