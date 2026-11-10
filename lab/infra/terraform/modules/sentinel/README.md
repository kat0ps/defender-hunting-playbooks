# sentinel module

Enables Microsoft Sentinel on a Log Analytics workspace and creates one scheduled analytics rule per YAML file in `rules_path` (see [`detections/sentinel/schema.md`](../../../../../detections/sentinel/schema.md)).

A rule is deployed only if **both** are true:

1. Its key (file name without `.yaml`) is in `enabled_rules` (or `enabled_rules` is `null`, meaning all).
2. Every table in its `requiredTables` is listed in `available_tables`. Sentinel rejects a rule whose tables don't exist in the workspace yet.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `workspace_id` | string | required | Resource ID of the Log Analytics workspace. |
| `rules_path` | string | required | Folder holding the rule YAML files. |
| `available_tables` | list(string) | `[]` | Tables that already have data in the workspace. |
| `enabled_rules` | list(string) | `null` (all) | Rule keys to deploy. |

## Outputs

| Name | Description |
|---|---|
| `sentinel_onboarding_id` | Resource ID of the Sentinel onboarding. |
| `deployed_rules` | Rule key => display name for each deployed rule. |
| `skipped_rules` | Enabled rules held back, with the tables each one is missing. |
| `missing_tables` | Every table blocking at least one enabled rule. |
| `not_enabled_rules` | Rules left out of `enabled_rules`. |
