# Data connectors

Each Sentinel rule reads one or more tables, and each table is filled by a data connector. Sentinel rejects a rule whose tables don't exist yet, so connect the data first, confirm rows arrive (Sentinel → Logs → `TableName | take 5`), then add the table to `available_tables` in `terraform.tfvars`.

## Connectors

| Connector (Content hub name) | connectorId | Tables these rules use | Needs |
|---|---|---|---|
| Microsoft Entra ID | `AzureActiveDirectory` | `SigninLogs`, `AADNonInteractiveUserSignInLogs` | Entra ID P1 or P2 licence (included in the M365 E5 trial) |
| Microsoft 365 (formerly Office 365) | `Office365` | `OfficeActivity` (tick Exchange) | An Exchange Online mailbox; audit logging on |
| Microsoft Defender XDR | `MicrosoftThreatProtection` | `DeviceProcessEvents`, `DeviceRegistryEvents`, `EmailEvents`, `EmailPostDeliveryEvents`, `UrlClickEvents` | Defender for Endpoint (device tables) and Defender for Office 365 P2 (email tables) |

## What each rule needs

| Rule | Connector | Tables |
|---|---|---|
| impossible-travel | Microsoft Entra ID | SigninLogs, AADNonInteractiveUserSignInLogs |
| aitm-automation-useragent-signin | Microsoft Entra ID | SigninLogs, AADNonInteractiveUserSignInLogs |
| aitm-click-then-new-ip-signin | Microsoft Entra ID + Defender XDR | SigninLogs, AADNonInteractiveUserSignInLogs, UrlClickEvents |
| aitm-session-replay-useragent-change | Microsoft Entra ID | SigninLogs, AADNonInteractiveUserSignInLogs |
| password-spray-compromise | Microsoft Entra ID | SigninLogs, AADNonInteractiveUserSignInLogs |
| legacy-auth-success | Microsoft Entra ID | SigninLogs, AADNonInteractiveUserSignInLogs |
| bec-suspicious-inbox-rule | Microsoft 365 | OfficeActivity |
| bec-external-forwarding | Microsoft 365 | OfficeActivity |
| bec-vip-impersonation | Defender XDR | EmailEvents |
| phishing-malicious-url-click | Defender XDR | UrlClickEvents, EmailEvents, EmailPostDeliveryEvents |
| powershell-office-child-process | Defender XDR | DeviceProcessEvents |
| powershell-encoded-download | Defender XDR | DeviceProcessEvents |
| powershell-clickfix-runmru | Defender XDR | DeviceRegistryEvents |
| powershell-defender-tampering | Defender XDR | DeviceProcessEvents |

Suggested order: Microsoft Entra ID first (unlocks 5 rules and is the quickest to produce data), then Microsoft 365, then Defender XDR.

## Cost warning

- **Defender XDR raw tables are billed as ingestion.** In the Defender XDR connector, tick only the five tables these rules need: `DeviceProcessEvents`, `DeviceRegistryEvents`, `EmailEvents`, `EmailPostDeliveryEvents`, `UrlClickEvents`. Leave the rest (especially `DeviceNetworkEvents`, `DeviceFileEvents` and `DeviceEvents`) unticked; they are the high-volume ones.
- **Keep the workspace daily cap on.** The `log-analytics` module sets `daily_quota_gb = 1`. When the cap is reached, collection stops until the next day, and the rules see no new data in that gap.
- `OfficeActivity` is free to ingest. Entra ID sign-in logs are billed, but a lab tenant produces very little.
- Check Cost Management weekly, and run `terraform destroy` when you finish the lab.
