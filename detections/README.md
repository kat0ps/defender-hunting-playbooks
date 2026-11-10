# Detection Rules

Rule-ready KQL for **Microsoft Defender XDR custom detection rules**. Each query is also a proactive hunt you can run by hand.

Every query returns the columns a custom detection needs: **`Timestamp`**, **`ReportId`**, and at least one entity column (`AccountObjectId`, `AccountUpn`, `DeviceId` or `RecipientEmailAddress`). Each file's header lists the playbook to follow when it fires, the severity, the run frequency, MITRE techniques, entity mapping and tuning notes.

## Rules

| Rule | Playbook | Severity | Frequency | MITRE | Status |
|---|---|---|---|---|---|
| [Impossible travel](impossible-travel.kql) | [Impossible travel](../playbooks/impossible-travel/README.md) | Medium | 24h | T1078.004 | Logic validated, rule untested |
| [AiTM: automation user agent sign-in](aitm-automation-useragent-signin.kql) | [AiTM / token theft](../playbooks/aitm-token-theft/README.md) | High | 1h | T1557, T1550.004 | Untested |
| [AiTM: click, then new-IP sign-in](aitm-click-then-new-ip-signin.kql) | [AiTM / token theft](../playbooks/aitm-token-theft/README.md) | High | 24h | T1566.002, T1557, T1539 | Untested |
| [AiTM: session replay with user agent change](aitm-session-replay-useragent-change.kql) | [AiTM / token theft](../playbooks/aitm-token-theft/README.md) | High | 24h | T1539, T1550.004 | Untested |
| [Password spray: password correct or signed in](password-spray-compromise.kql) | [Password spray](../playbooks/password-spray/README.md) | High | 3h | T1110.003, T1078.004 | Untested |
| [Legacy authentication success](legacy-auth-success.kql) | [Password spray](../playbooks/password-spray/README.md) | Medium | 1h | T1078.004 | Untested |
| [BEC: high-risk inbox rule](bec-suspicious-inbox-rule.kql) | [BEC](../playbooks/business-email-compromise/README.md) | High | 1h | T1564.008, T1114.003 | Untested |
| [BEC: external forwarding](bec-external-forwarding.kql) | [BEC](../playbooks/business-email-compromise/README.md) | High | 1h | T1114.003 | Untested |
| [BEC: VIP display name impersonation](bec-vip-impersonation.kql) | [BEC](../playbooks/business-email-compromise/README.md) | Medium | 1h | T1656 | Untested |
| [Phishing: malicious URL click](phishing-malicious-url-click.kql) | [Phishing triage](../playbooks/phishing-triage/README.md) / [User-reported email](../playbooks/user-reported-email/README.md) | High | 1h | T1204.001, T1566.002 | Untested |
| [PowerShell: Office spawning script engines](powershell-office-child-process.kql) | [Suspicious PowerShell](../playbooks/suspicious-powershell/README.md) | High | 1h / NRT | T1204.002, T1059.001 | Untested |
| [PowerShell: encoded download/execute](powershell-encoded-download.kql) | [Suspicious PowerShell](../playbooks/suspicious-powershell/README.md) | High | 1h | T1059.001, T1027.010, T1105 | Untested |
| [PowerShell: ClickFix (Run dialog)](powershell-clickfix-runmru.kql) | [Suspicious PowerShell](../playbooks/suspicious-powershell/README.md) | High | 1h / NRT | T1204.004 | Untested |
| [PowerShell: Defender/AMSI tampering](powershell-defender-tampering.kql) | [Suspicious PowerShell](../playbooks/suspicious-powershell/README.md) | High | 1h | T1562.001, T1070.001 | Untested |

> The user-reported email playbook is triggered by Microsoft's built-in *Email reported by user as malware or phish* alert, so it has no separate rule. The malicious URL click rule covers the follow-up risk.

## Deploying a rule

1. **Fill in the variables** at the top (`internalDomains`, `vipNames`, `excludedAccounts`, `excludedRanges`).
2. **Run it as a hunt first** over 30 days (temporarily widen the `ago()`). If it returns too many rows, tune it before creating the rule.
3. In Advanced Hunting, select **Create detection rule**:
   - **Name / severity / MITRE:** copy them from the file header.
   - **Frequency:** use the one in the header. Each query's `ago()` already matches the lookback Defender allows for that frequency (1h → 4h, 3h → 12h, 24h → up to 30 days).
   - **Impacted entities:** map the columns listed under *Entities* in the header.
   - **Actions (optional):** start with **no automated actions**. Add them (isolate device, mark user compromised) only after the rule has proven reliable.
4. **Update the Status column** in this table once the rule has run cleanly for a week.

## Status key

- **Untested:** written, not yet run in a live tenant.
- **Hunt validated:** runs without errors and the results make sense as a manual hunt.
- **Rule deployed:** live as a custom detection, with false positives tuned.
