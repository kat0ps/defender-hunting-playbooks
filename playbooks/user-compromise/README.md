# Playbook: User Compromise (Account Takeover)

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** *Risky user* / *User at risk* (Entra ID Protection), *Suspicious sign-in*, a user reporting MFA prompts they didn't start or email they didn't send, a client or supplier reporting strange email from the account, or another playbook finding a compromised account
**MITRE ATT&CK:** T1078.004 Valid Accounts: Cloud · T1110 Brute Force · T1621 MFA Request Generation · T1539 Steal Web Session Cookie · T1098.005 Device Registration · T1114.003 Email Forwarding Rule · T1534 Internal Spearphishing · T1530 Data from Cloud Storage

---

## How the attack works

The attacker gets the user's password or session token through phishing (often AiTM), password spray, or a leaked or stolen credential. They sign in from a new IP and add persistence such as a new MFA method, a registered device or an OAuth app. Then they hide in the mailbox with inbox rules, read mail, and use the account for internal phishing, payment fraud or data theft. In the logs this shows up as a new IP, device or user agent, followed by identity changes, mailbox rules and unusual email or file activity.

Use this playbook when you don't know yet how the account was compromised. If the alert already tells you, start in the specific playbook (see **Then** below) and come back here to scope the damage.

## Before you start

| Variable | Example |
|---|---|
| `user` | `user@domain.com` |
| `suspectTime` | `datetime(2026-11-25 08:00:00)` (UTC: alert time, or when the user noticed something) |
| `badIPs` | `dynamic(["x.x.x.x","y.y.y.y"])` (fill in after step 3) |
| `myDomain` | `domain.com` |

- Check the incident's automated investigation and any attack simulation (Attack simulation training) before you start.
- Contact the user **by phone or Teams call**, not email: the mailbox may be read by the attacker.
- If money may be moving (payment fraud), tell finance now. Don't wait for the verdict.

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | User profile | [01-user-profile.kql](queries/01-user-profile.kql) | Role, department, whether the account is enabled. Finance, execs and admins raise the priority. |
| 1b | Alerts on the user | [01b-user-alerts.kql](queries/01b-user-alerts.kql) | Other alerts in 30 days: phishing clicks, infostealer on their device, risky sign-ins |
| 2 | Risky sign-ins | [02-risky-signins.kql](queries/02-risky-signins.kql) | Entra ID Protection detections (`RiskEventTypes`) and `RiskState` on successful sign-ins |
| 3 | Sign-in baseline | [03-signin-baseline.kql](queries/03-signin-baseline.kql) | New country, ISP, device or user agent near `suspectTime` (`NewNearSuspect = true`). These IPs become `badIPs`. |
| 4 | Authentication timeline | [04-auth-method-timeline.kql](queries/04-auth-method-timeline.kql) | Spray (bad passwords then success), MFA fatigue (repeated denials), single-factor or legacy auth |
| 5 | Session / token replay | [05-session-token-replay.kql](queries/05-session-token-replay.kql) | One `SessionId` from several IPs, countries or user agents = stolen cookie or token |
| 6 | Attacker IP timeline | [06-attacker-ip-timeline.kql](queries/06-attacker-ip-timeline.kql) | Everything `badIPs` did, sign-ins and cloud activity together, in order |
| 7 | Persistence | [07-persistence.kql](queries/07-persistence.kql) | New MFA methods, devices, OAuth consents, password changes or roles, especially from `badIPs` |
| 8 | Mailbox rules and forwarding | [08-mailbox-rules-forwarding.kql](queries/08-mailbox-rules-forwarding.kql) | Rules that hide, delete or forward mail; external forwarding; new mailbox permissions |
| 9 | Mailbox activity | [09-mailbox-activity.kql](queries/09-mailbox-activity.kql) | Mail read, sent, edited or deleted from `badIPs` (`FromBadIP = true`) |
| 10 | Outbound email | [10-outbound-email.kql](queries/10-outbound-email.kql) | Bursts of email, finance or "shared document" subjects, unusual recipients |
| 11 | Data access | [11-data-access.kql](queries/11-data-access.kql) | Bulk downloads, anonymous links or external sharing from `badIPs` |
| 12 | Initial access | [12-initial-access.kql](queries/12-initial-access.kql) | Phishing emails or link clicks just before the first suspicious sign-in |
| 13 | Blast radius: IPs | [13-blast-radius-ips.kql](queries/13-blast-radius-ips.kql) | Other accounts signing in from `badIPs` |
| 13b | Blast radius: recipients | [13b-blast-radius-recipients.kql](queries/13b-blast-radius-recipients.kql) | Who got mail from the account after `suspectTime`, and who clicked |

**Then:**
- Link click before the sign-in (step 12) or token replay (step 5) → [AiTM / token theft](../aitm-token-theft/README.md)
- Bad passwords then success (step 4) → [Password spray](../password-spray/README.md)
- Leaked credentials in step 2 → [Leaked credentials](../leaked-credentials/README.md)
- Inbox rules, forwarding or payment emails (steps 8–10) → [Business email compromise](../business-email-compromise/README.md)
- Foreign sign-in that could be travel → [Impossible travel](../impossible-travel/README.md) steps 4b–4d

## Triage at a glance

| What you see | What it means | Action |
|---|---|---|
| New IP, but same device, managed, MFA done interactively, nothing in steps 7–11 | Probably the user on a new network or VPN | Confirm with the user by phone, close as benign |
| New IP with an unmanaged device or a non-browser user agent (python, axios, curl) | Likely attacker tooling | Treat as compromised, continue to step 5 |
| Same `SessionId` from two countries (step 5) | Stolen token or cookie | Revoke sessions now; a password reset alone won't remove them |
| New MFA method or device from a `badIP` (step 7) | Attacker persistence | Remove it during containment, then check how they passed MFA |
| Inbox rule hiding finance mail or forwarding outside (step 8) | BEC in progress | Contain, then run the BEC playbook |
| Email burst to many recipients (step 10) | Internal or external phishing from the account | Purge the emails, warn recipients, run step 13b |

## Field notes

- **Work out `badIPs` early.** Steps 6, 9, 11 and 13 all depend on it. Add IPs as you find them and re-run.
- **Non-interactive sign-ins** (token refreshes, e.g. Microsoft Authentication Broker) carry the MFA claim from the original sign-in. They don't prove the person at that IP passed MFA.
- **`ConditionalAccessStatus = 2` (notApplied)** on the suspicious sign-in means no Conditional Access policy covered it. Raise it as a gap even if the case is benign.
- **`MailItemsAccessed` needs Audit Premium.** If step 9 shows no reads at all, check the licence before you conclude nothing was read.
- **Attackers act fast.** With a stolen token, rules and email usually follow within hours. Clean steps 7–11 several days later count against compromise.
- **Don't warn the user by email** and don't email the client from the affected mailbox until containment is done.

## Common false positives

- **VPN, Zscaler, Netskope or cloud egress IPs** that geolocate far away. Same device and session on both sides = network routing.
- **Mobile carrier IPs** that geolocate to the carrier's hub city.
- **Travel.** Confirm through another channel (use the [travel confirmation email](../../templates/travel-confirmation-email.md) to the manager).
- **Helpdesk changes.** A password reset or MFA re-registration done by IT. Check the actor in step 7's `RawEventData`.
- **New phone.** A new device and MFA method from the user's usual home or office IP, confirmed by the user.

## Verdict

**Likely benign** if *all* of these are true:
- The new sign-in uses a known device, or a known VPN or carrier IP
- MFA was satisfied interactively on a managed or compliant device
- No token replay (step 5) and no unexpected changes or activity in steps 7–11
- The user confirms the activity by phone

**Likely compromised** if *any* of these are true:
- A successful sign-in from a new IP with an unmanaged device, a non-browser user agent, or single-factor or legacy auth
- One session used from more than one country (step 5)
- MFA methods, devices or OAuth apps added from a `badIP`
- Inbox rules, forwarding, mail deletion, or email the user didn't send
- Entra ID Protection marks the user `confirmedCompromised`, or the user denies the activity

## Containment

Work through these in order:

1. [ ] **Revoke all sessions** (Entra ID → user → *Revoke sessions*), or disable the account if the attacker is active.
2. [ ] **Reset the password** and mark the user as compromised in Entra ID Protection.
3. [ ] **Remove attacker MFA methods, registered devices and OAuth app consents** (step 7).
4. [ ] **Delete malicious inbox rules, forwarding and mailbox permissions** (step 8). Also check `Get-InboxRule -IncludeHidden` in Exchange Online PowerShell.
5. [ ] **Block `badIPs`** with a Conditional Access named location or Defender indicators.
6. [ ] **Purge phishing or fraud emails** the account sent (Threat Explorer) and **warn recipients**, by phone for clients and suppliers (steps 10, 13b).
7. [ ] **Contact finance** to hold or recall any payment made because of email from the account.
8. [ ] **Investigate every other account** found in step 13.
9. [ ] **Check the user's devices** for malware or an infostealer if no phishing click explains the access (step 12).
10. [ ] **Document the findings**: timeline, IOCs, root cause, and what the attacker accessed.

## Related detection rules

- [Impossible travel](../../detections/impossible-travel.kql)
- [AiTM click then new-IP sign-in](../../detections/aitm-click-then-new-ip-signin.kql)
- [AiTM session replay (user agent change)](../../detections/aitm-session-replay-useragent-change.kql)
- [Password spray compromise](../../detections/password-spray-compromise.kql)
- [Legacy auth success](../../detections/legacy-auth-success.kql)
- [BEC high-risk inbox rule](../../detections/bec-suspicious-inbox-rule.kql)
- [BEC external forwarding](../../detections/bec-external-forwarding.kql)

## Templates

- Closure: [closure-notes.md](../../templates/closure-notes.md)
- Escalation: [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- Full write-up: [incident-report.md](../../templates/incident-report.md)
