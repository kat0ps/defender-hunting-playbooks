# Sentinel rule YAML schema

Each `*.yaml` file in this folder is one **Microsoft Sentinel scheduled analytics rule**. It's converted from the Defender XDR rule with the same name in [`../`](../README.md).

Terraform (`lab/infra/terraform/modules/sentinel`) loads every file with `fileset()` + `yamldecode()` and creates one `azurerm_sentinel_alert_rule_scheduled` per file. `lab/scripts/validate_detections.py` checks the files in CI before Terraform ever sees them.

The file name (without `.yaml`) is the rule's **key**. It's the name you put in the Terraform `enabled_rules` variable, for example `enabled_rules = ["legacy-auth-success"]`.

| Field | Required | Terraform argument | What it means |
|---|---|---|---|
| `id` | ✅ | `name` | A stable GUID and the rule's ARM resource name. **Never change it.** A new id makes Terraform delete the rule and create a new one, which loses its incident history. These ids were generated with `uuid5` from the rule name, so they're reproducible. |
| `name` | ✅ | `display_name` | The title shown under Sentinel → Analytics and on every incident. |
| `description` | ✅ | `description` | What the rule detects, the MITRE sub-techniques, and a link to the playbook to follow. |
| `severity` | ✅ | `severity` | `Informational`, `Low`, `Medium` or `High`. |
| `enabled` | ✅ | `enabled` | `false` creates the rule switched off. To keep a rule out of Sentinel completely, use the `enabled_rules` variable instead. |
| `queryFrequency` | ✅ | `query_frequency` | How often the query runs, as an ISO 8601 duration between `PT5M` and `P14D`. Write whole days as `P1D`, not `PT24H`: the API returns `P1D`, and `PT24H` would make Terraform report a change on every plan. |
| `queryPeriod` | ✅ | `query_period` | How far back each run looks (`PT5M` to `P14D`). Sentinel applies this time filter itself, so most queries don't need their own `ago()`. |
| `triggerOperator` | ✅ | `trigger_operator` | `GreaterThan`, `LessThan`, `Equal` or `NotEqual`. |
| `triggerThreshold` | ✅ | `trigger_threshold` | Used with the operator. `GreaterThan 0` means "alert when the query returns any rows". |
| `tactics` | ✅ | `tactics` | MITRE tactics in Sentinel's spelling, with no spaces: `InitialAccess`, `CredentialAccess`, `DefenseEvasion` and so on. |
| `techniques` | ✅ | `techniques` | **Parent** technique IDs only (`T1078`, not `T1078.004`). Sub-techniques go in the description. |
| `entityMappings` | ✅ | `entity_mapping` blocks | Tells Sentinel which result columns are users, IPs, hosts, mailboxes and URLs. Incidents use entities to group alerts and to link to user and host pages. At most 10 mappings with up to 3 identifiers each. |
| `requiredDataConnectors` | ✅ | (docs only) | Which Sentinel data connector feeds each table: `AzureActiveDirectory` (Entra ID), `Office365` (OfficeActivity), `MicrosoftThreatProtection` (Defender XDR raw tables). |
| `requiredTables` | ✅ | (deploy gate) | Every table the query reads. Sentinel rejects a rule if any of these tables doesn't exist in the workspace yet, so Terraform only creates the rule when all of them are listed in `available_tables`. |
| `sourceRule` | ✅ | (docs only) | Relative path to the original Defender XDR `.kql` file. |
| `query` | ✅ | `query` | The KQL, converted for a Log Analytics workspace (max 10,000 characters). |

### Entity mapping identifiers used

| Entity type | Identifier | Typical column |
|---|---|---|
| `Account` | `AadUserId` | `UserId` (sign-in logs), `AccountObjectId` (Device tables) |
| `Account` | `FullName` | `UserPrincipalName`, `AccountUpn`, `UserId` in OfficeActivity (it holds the UPN there) |
| `IP` | `Address` | `IPAddress`, `ClientIPAddress` |
| `Host` | `HostName` | `HostName` (short name computed from the `DeviceName` FQDN) |
| `Mailbox` | `MailboxPrimaryAddress` | `RecipientEmailAddress` |
| `URL` | `Url` | `Url` |

### Defender XDR → Sentinel conversion cheat sheet

| Defender XDR | Sentinel workspace |
|---|---|
| `Timestamp` | `TimeGenerated` |
| `ReportId` | removed (Sentinel creates its own alert ids) |
| `EntraIdSignInEvents` | `SigninLogs` + `AADNonInteractiveUserSignInLogs` (union) |
| `AccountUpn` / `AccountObjectId` | `UserPrincipalName` / `UserId` |
| `ErrorCode == 0` (int) | `ResultType == "0"` (**string**) |
| `Country`, `City`, `Latitude`, `Longitude` | `LocationDetails.countryOrRegion`, `.city`, `.geoCoordinates.latitude/longitude` |
| `Application` | `AppDisplayName` |
| `AadDeviceId`, `IsManaged`, `IsCompliant`, `OSPlatform`, `Browser` | `DeviceDetail.deviceId`, `.isManaged`, `.isCompliant`, `.operatingSystem`, `.browser` |
| `LogonType` | `IsInteractive` (bool) |
| `CloudAppEvents` (Exchange cmdlets) | `OfficeActivity`: `ActionType`→`Operation`, `RawEventData.Parameters`→`Parameters`, `RawEventData.ObjectId`→`OfficeObjectId`, `IPAddress`→`ClientIP` (strip the port), `AccountObjectId`→`UserId` (UPN) |
| `CountryCode`, `ISP` (CloudAppEvents) | no OfficeActivity equivalent (dropped) |
| `EmailEvents`, `UrlClickEvents`, `EmailPostDeliveryEvents`, `Device*` | same names and columns (streamed by the Defender XDR connector) |

`LocationDetails` and `DeviceDetail` are `dynamic` in `SigninLogs` but `string` in `AADNonInteractiveUserSignInLogs`. That's why every sign-in rule calls `parse_json()` on the non-interactive leg of the union.
