# Playbook: Impossible Travel / Entra ID Account Compromise

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** *Atypical travel*, *Impossible travel activity*, *Activity from infrequent country*, or the custom [impossible travel detection](../../detections/impossible-travel.kql)
**MITRE ATT&CK:** T1078.004 Valid Accounts: Cloud · T1539 Steal Web Session Cookie · T1110.003 Password Spraying · T1621 MFA Request Generation · T1114.003 Email Forwarding Rule · T1098.005 Device Registration

---

## Before you start

Gather these values (step 1 gives you most of them) and fill them into the `let` lines of each query:

| Variable | Example |
|---|---|
| `alertId` | `da638...` |
| `user` | `user@domain.com` |
| `alertTime` | `datetime(2026-11-09 08:00:00)` (UTC) |
| `badIP` / `badIPs` | `"x.x.x.x"` / `dynamic(["x.x.x.x","y.y.y.y"])` |

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 0 | Existing travel alerts *(optional)* | [00-existing-travel-alerts.kql](queries/00-existing-travel-alerts.kql) | Other travel alerts for the same user or time period |
| 1 | Alert scope | [01-alert-scope.kql](queries/01-alert-scope.kql) | User, IPs, devices and time from the alert evidence |
| 2 | Baseline vs new IPs | [02-baseline-new-ips.kql](queries/02-baseline-new-ips.kql) | IPs, countries or user agents first seen around the alert (`NewNearAlert = true`), unmanaged devices |
| 3 | Authentication details | [03-auth-details.kql](queries/03-auth-details.kql) | Password spray (many bad passwords, then success), MFA fatigue (repeated denials), single-factor auth, legacy protocols |
| 4 | Token replay | [04-token-replay.kql](queries/04-token-replay.kql) | One `SessionId` used from several countries or IPs, which suggests cookie or token theft (AiTM) |
| 5 | Persistence | [05-persistence.kql](queries/05-persistence.kql) | New MFA methods, device registrations, OAuth consents, password changes from the suspicious IP |
| 6 | Mailbox abuse | [06-mailbox-abuse.kql](queries/06-mailbox-abuse.kql) | Inbox rules that forward, delete, mark as read or move mail to RSS Feeds/Archive; mailbox forwarding; delegation |
| 7 | Outbound email | [07-outbound-email.kql](queries/07-outbound-email.kql) | Bursts of internal or external phishing, BEC-style subjects |
| 8 | Data access | [08-data-access.kql](queries/08-data-access.kql) | Bulk downloads, anonymous or external sharing links |
| 9 | Blast radius | [09-blast-radius.kql](queries/09-blast-radius.kql) | Other accounts signing in from the same suspicious IPs |

---

## Common false positives

- **VPN, proxy or cloud egress** (Zscaler, Netskope, Azure/AWS ranges). Add these ranges to `excludedRanges` in the detection.
- **Mobile carrier IPs** that geolocate to the carrier's hub city rather than where the user is.
- **The same device and session on both sides** (`SameDevice` / `SameSession` = true). This is almost always network routing, not two people.
- **Travelling users.** Check with the user or their manager through a channel other than the possibly compromised mailbox.

## Verdict

**Likely benign** if *all* of these are true:
- The same device or session appears on both sides of the alert, or the IP belongs to a known VPN or proxy
- MFA was satisfied interactively on a managed or compliant device
- Steps 5–8 show no suspicious changes or activity

**Likely compromised** if *any* of these are true:
- The IP, device or user agent is new and the device is unmanaged
- The suspicious sign-in used single-factor or legacy auth
- One session appears in several countries (step 4)
- MFA methods or devices were added, inbox rules or forwarding were created, or unusual email or file activity followed the sign-in

## Containment (true positive)

Work through these in order:

1. [ ] **Revoke all sessions** (Entra ID → user → *Revoke sessions*), or disable the account. Essential if step 4 found token replay.
2. [ ] **Reset the password**, and mark the user as compromised in Entra ID Protection.
3. [ ] **Remove attacker-added MFA methods and registered devices** (step 5).
4. [ ] **Delete malicious inbox rules and mailbox forwarding**, and remove delegations (step 6).
5. [ ] **Revoke OAuth app consents** the attacker granted (step 5).
6. [ ] **Block the malicious IPs** (Conditional Access named location or Defender indicators).
7. [ ] **Investigate every other account** found in step 9, and notify recipients of any phishing from step 7.
8. [ ] **Document the findings**: timeline, IOCs, root cause (e.g. AiTM phishing, password spray).

