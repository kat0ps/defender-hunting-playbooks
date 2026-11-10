# Defender XDR Hunting Playbooks

Investigation playbooks and KQL queries for **Microsoft Defender XDR Advanced Hunting**.

Each playbook walks through an investigation from alert to verdict to containment, with ready-to-paste queries.

> **Table note:** Queries use `EntraIdSignInEvents`. If your tenant doesn't have it yet, swap in `AADSignInEventsBeta`, which has the same columns.
> **Retention:** Advanced Hunting keeps 30 days of data, so keep lookbacks at or under `30d`.

## Playbooks

| Playbook | Area | Use when | MITRE ATT&CK |
|---|---|---|---|
| [Impossible travel / account compromise](playbooks/impossible-travel/README.md) | Identity | An Atypical travel / Impossible travel alert fires, or you suspect a compromised Entra ID account | T1078.004, T1539, T1114.003 |
| [AiTM phishing / token theft](playbooks/aitm-token-theft/README.md) | Identity | A phishing click is followed by a sign-in from a new IP, or an AiTM / stolen-cookie alert fires | T1557, T1539, T1550.004 |
| [Password spray / brute force](playbooks/password-spray/README.md) | Identity | Many failed sign-ins across users, lockout spikes, or a password spray alert | T1110.003, T1110.001 |
| [User-reported email](playbooks/user-reported-email/README.md) | Email | An *Email reported by user as malware or phish* alert, or a Report-button submission | T1566.001, T1566.002, T1656 |
| [Phishing email triage](playbooks/phishing-triage/README.md) | Email | A user-reported phish, malicious URL click, or post-delivery removal alert | T1566.001, T1566.002, T1204 |
| [Business email compromise](playbooks/business-email-compromise/README.md) | Email | A suspicious inbox rule or forwarding, a banking-details change request, or payment fraud | T1114.003, T1564.008, T1534, T1656 |
| [Suspicious PowerShell](playbooks/suspicious-powershell/README.md) | Endpoint | An encoded or obfuscated PowerShell alert, an Office app spawning scripts, or ClickFix | T1059.001, T1027.010, T1105, T1204.004 |

### How the playbooks connect

```
User-reported email ──malicious──▶ Phishing triage
Phishing triage ──clicked link──▶ AiTM / token theft ──▶ Impossible travel (scope the account)
       │                                                        ▲
       └──ran attachment──▶ Suspicious PowerShell               │
Password spray ──successful sign-in────────────────────────────┘
Business email compromise ◀──inbox rules / fraud emails── any compromised account
```

## Detections

**14 rule-ready detections** (Timestamp, ReportId and entity columns included) that you can run as hunts or deploy as Defender custom detection rules. Each one links back to the playbook to follow when it fires.

See the **[detections index](detections/README.md)** for severity, frequency, MITRE techniques, deployment steps and test status.

| Area | Rules |
|---|---|
| Identity | Impossible travel · AiTM automation user agent · AiTM click then new-IP sign-in · AiTM session replay · Password spray compromise · Legacy auth success |
| Email | BEC high-risk inbox rule · BEC external forwarding · BEC VIP impersonation · Malicious URL click |
| Endpoint | Office spawning script engines · Encoded PowerShell download · ClickFix (Run dialog) · Defender/AMSI tampering |

## Templates

| Template | Use it for |
|---|---|
| [incident-report.md](templates/incident-report.md) | A full write-up for true positives: summary, timeline, scope, IOCs, remediation, lessons learned |
| [closure-notes.md](templates/closure-notes.md) | Short notes to paste into the ticket: false positive, benign true positive, true positive |
| [escalation-compromise-email.md](templates/escalation-compromise-email.md) | An urgent client email when compromise is confirmed or suspected |
| [travel-confirmation-email.md](templates/travel-confirmation-email.md) | Asking the client to confirm user travel (impossible travel alerts) |
| [phishing-user-notification-email.md](templates/phishing-user-notification-email.md) | Telling recipients a phishing email was removed |
| [playbook-template.md](templates/playbook-template.md) | Starting a new playbook in the standard format |
| [detection-rule-template.kql](templates/detection-rule-template.kql) | Starting a new detection rule with the required columns and header |

## Repo layout

```
playbooks/<scenario>/README.md      # step-by-step investigation guide
playbooks/<scenario>/queries/*.kql  # one query per step, numbered in order
detections/*.kql                    # rule-ready hunts / custom detection rules (index in detections/README.md)
templates/                          # playbook, detection, report, closure and email templates
```

## How to use

1. Open the playbook for your alert type.
2. Fill in the `let` variables at the top of each query (user, alert time, IPs).
3. Run the queries in order and use the **Verdict** section to make a call.
4. If it's a true positive, follow the **Containment** checklist.
5. Close it out with the matching template: closure notes for every alert, plus an incident report and escalation email for true positives.

## Changelog

- **2026-11-10**: Added 13 new detection rules (14 total) with a detections index; made impossible travel rule-ready. Added templates: incident report, closure notes, escalation email, phishing user notification, detection rule. Updated the playbook template. Linked rules and templates from every playbook.
- **2026-11-10**: Added user-reported email playbook (M365 suspicious user submission): one-row triage summary, all submissions, similar reports, sender reputation.
- **2026-11-10**: Added 5 playbooks: AiTM / token theft, password spray, phishing triage, business email compromise, suspicious PowerShell (including ClickFix). Added area and MITRE columns to the index.
- **2026-11-09**: Added travel confirmation email template and a field note on reading the alert activity log.
- **2026-11-09**: Impossible travel playbook: added 04d home device activity, plus field notes on out-of-office, travel routes and eSIMs.
- **2026-11-09**: Impossible travel playbook: added 04b session timeline, 04c IP enrichment, 05b identity change details, and field notes (broker tokens, CA notApplied, Update user bursts).
- **2026-11-09**: Initial release: impossible travel detection and account compromise playbook.
