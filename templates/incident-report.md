# Incident Report: <Short title, e.g. "Compromised mailbox used for invoice fraud">

| | |
|---|---|
| **Incident / ticket ID** | <ID> |
| **Client / business unit** | <Name> |
| **Severity** | Low / Medium / High / Critical |
| **Status** | Open / Contained / Closed |
| **Classification** | True positive / Benign true positive / False positive |
| **Analyst** | <Name> |
| **Report date** | <YYYY-MM-DD> |
| **Playbook used** | <link to playbook> |

---

## 1. Executive summary

<Three to five sentences for a non-technical reader: what happened, who was affected, whether data or money was at risk, what has been done, and what still needs doing.>

## 2. Detection

- **Alert:** <alert title, source (e.g. Defender for Cloud Apps), time>
- **How it was detected:** <built-in alert / custom detection rule / user report / threat hunt>

## 3. Scope

| Type | Value |
|---|---|
| Affected users | <UPNs> |
| Affected devices | <device names> |
| Affected mailboxes / data | <mailboxes, files, systems> |
| Time window | <first malicious activity> → <last malicious activity> |

## 4. Timeline (UTC+2)

| Time | Event | Source |
|---|---|---|
| <YYYY-MM-DD HH:MM> | <e.g. phishing email delivered to 12 users> | EmailEvents |
| <YYYY-MM-DD HH:MM> | <e.g. user clicked link> | UrlClickEvents |
| <YYYY-MM-DD HH:MM> | <e.g. sign-in from proxy IP x.x.x.x> | EntraIdSignInEvents |
| <YYYY-MM-DD HH:MM> | <e.g. inbox rule created> | CloudAppEvents |
| <YYYY-MM-DD HH:MM> | <e.g. sessions revoked> | Analyst action |

## 5. Findings

<What the investigation established, step by step. Reference the playbook steps and queries used. State clearly what was **not** found too, e.g. "no mailbox rules, no file downloads".>

## 6. Root cause

<How access or execution was achieved, e.g. AiTM phishing, password spray against an account without MFA, malicious attachment, ClickFix lure.>

## 7. Indicators of compromise

| Type | Value | Notes |
|---|---|---|
| IP | <x.x.x.x> | <ISP / country / role> |
| Domain / URL | <domain> | <phishing page / C2> |
| File hash (SHA256) | <hash> | <file name> |
| Email sender | <address> | <campaign> |

## 8. Containment and remediation

| Action | Done by | Time |
|---|---|---|
| <Revoked sessions for user@domain> | <Name> | <time> |
| <Reset password> | | |
| <Removed inbox rule ".."> | | |
| <Purged phishing email from 12 mailboxes> | | |
| <Blocked IPs / domains / hashes> | | |

## 9. Recommendations

1. <e.g. Enforce phishing-resistant MFA for finance users>
2. <e.g. Block legacy authentication with Conditional Access>
3. <e.g. Disable automatic external forwarding>

## 10. Lessons learned

- **What worked:** <e.g. the user reported the email within 10 minutes>
- **What to improve:** <e.g. the CA policy gap allowed an unmanaged device; a detection rule would have caught this sooner>
- **Playbook or detection updates:** <link to the commit or change>
