# Playbook: Activity from an Anonymous Proxy

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** *Activity from an anonymous proxy* / *Activity from anonymous IP addresses* (Defender for Cloud Apps), *Anonymous IP address* (Entra ID Protection risk detection), *Activity from a Tor IP address*
**MITRE ATT&CK:** T1090.002 External Proxy · T1090.003 Multi-hop Proxy · T1078.004 Valid Accounts: Cloud · T1550.004 Web Session Cookie

---

## How the attack works

Attackers who hold a user's password or session cookie sign in through a commercial VPN, Tor or an open proxy, so the activity can't be traced back to them and gets past simple country blocks. Defender for Cloud Apps and Entra ID Protection tag these IPs as anonymous. The catch is that plenty of real users do the same thing on purpose: personal VPN apps, iCloud Private Relay, privacy browsers. So the alert tells you about the **network**, not the **person**. Your job is to work out whether it was the user on a VPN or someone else using their account.

**What it looks like in the logs:**
- `IsAnonymousProxy = true` in `CloudAppEvents`, and `anonymizedIPAddress` in `RiskEventTypes` in `EntraIdSignInEvents`
- An ISP that is a VPN brand, a hosting provider or a Tor exit, often in a country the user has never been seen in
- If malicious: a device, user agent or session that doesn't match the user's normal ones, followed by mailbox, file or MFA changes from the same IP

## Before you start

Gather these values (step 1 gives you most of them) and fill them into the `let` lines of each query:

| Variable | Example |
|---|---|
| `alertId` | `ca5f2...` |
| `user` | `user@domain.com` |
| `alertTime` | `datetime(2026-11-16 08:00:00)` (UTC) |
| `ips` | `dynamic(["x.x.x.x","y.y.y.y"])` |
| `isps` | `dynamic(["<ISP from step 3>"])` |

Open the alert in Defender and use **Investigate in activity log** (Defender for Cloud Apps) to see the exact activities that triggered it.

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Alert scope | [01-alert-scope.kql](queries/01-alert-scope.kql) | User, proxy IP(s), application and time from the alert evidence |
| 2 | Flagged activities | [02-flagged-activities.kql](queries/02-flagged-activities.kql) | What was done from the proxy: only sign-ins, or mail access, downloads or admin changes? `UncommonForUser` shows what was new for this user |
| 3 | IP enrichment | [03-ip-enrichment.kql](queries/03-ip-enrichment.kql) | Who runs the IP: commercial VPN, Tor, iCloud Private Relay, hosting, or your own corporate egress (many users, every day) |
| 4 | User's proxy history | [04-user-proxy-history.kql](queries/04-user-proxy-history.kql) | Does this user use the same proxy provider every day (habit), or did it first appear around the alert? |
| 5 | Sign-in details | [05-signin-details.kql](queries/05-signin-details.kql) | Single-factor or legacy auth, failures before success, unmanaged device, automation user agent, CA not applied |
| 6 | Session link | [06-session-link.kql](queries/06-session-link.kql) | Is the proxy session the same device and user agent as the user's normal sessions (VPN on and off), or a different one (token replay)? |
| 7 | Post-access actions | [07-post-access-actions.kql](queries/07-post-access-actions.kql) | Inbox rules, forwarding, mail access, downloads, sharing links, MFA or device registration, app consent, especially with `FromProxy = true` |
| 8 | Blast radius | [08-blast-radius.kql](queries/08-blast-radius.kql) | Other accounts on the same proxy IPs or provider |

**Then:** if the account looks compromised, run the [impossible travel playbook](../impossible-travel/README.md) steps 5–9 for full persistence and mailbox scoping. If step 8 shows many accounts with failures, switch to the [password spray playbook](../password-spray/README.md). If the session came straight after a phishing click, use the [AiTM playbook](../aitm-token-theft/README.md).

## Triage at a glance

| What you see | What it means | Action |
|---|---|---|
| Same ISP every day for weeks, same device and user agent, MFA satisfied | The user runs a VPN app | Confirm with the user, close as benign true positive |
| Many users on the IP daily, ISP is your SSE/VPN vendor | Corporate egress tagged as anonymous | Add the range in Defender for Cloud Apps **IP address ranges** as Corporate/VPN, close as false positive |
| Safari or iOS, ISP is Akamai, Cloudflare or Fastly | Likely iCloud Private Relay | Confirm device matches, close as benign |
| Tor exit node | Rarely legitimate in a business tenant | Treat as suspicious until the user explains it |
| New device or user agent, single-factor or legacy auth | Someone else may have the password | Escalate, revoke sessions, reset password |
| Session seen on the proxy with a different user agent than on the normal IP | Possible stolen session cookie | Revoke sessions, run the AiTM playbook |
| Inbox rules, MFA registration or downloads from the proxy IP | Compromise in progress | Containment now |

## Field notes

- **`IsAnonymousProxy` comes from Microsoft's IP intelligence, and it misses things.** Residential proxy networks, which attackers increasingly use, usually aren't tagged. A clean flag doesn't clear an IP, and a flagged IP doesn't convict one.
- **Consumer VPNs exit through hosting ranges.** A VPN brand or hosting ISP in step 3 fits the "user's VPN" story; a residential ISP abroad does not.
- **Look at the order of IPs in step 6.** A user turning a VPN on and off shows the same `SessionId`, `UserAgent` and `AadDeviceId` alternating between home and proxy IPs. Replay usually shows the proxy session appearing with a different browser or OS, or only ever on the proxy.
- **Token refreshes inherit MFA.** Non-interactive sign-ins from the proxy showing `multiFactorAuthentication` don't prove the person behind the proxy passed MFA. Look for the first interactive sign-in from that IP.
- **`ConditionalAccessStatus = 2` (notApplied)** on proxy sign-ins is a coverage gap worth raising even if the case is benign. Consider a CA policy that blocks or requires MFA for high sign-in risk, which includes anonymous IPs.
- **Ask the user through a channel other than their mailbox** (phone, Teams from a known device). If the account is compromised, the attacker may read and answer the email.

## Common false positives

- **Personal VPN apps** (NordVPN, ExpressVPN, Proton VPN, Surfshark and so on), especially on phones. Steps 4 and 6 show the same provider and device over weeks.
- **iCloud Private Relay** in Safari and iOS Mail. Egress comes from Akamai, Cloudflare or Fastly ranges.
- **Corporate VPN or SSE egress** (Zscaler, Netskope, Cloudflare WARP) that Defender doesn't know is yours. Many users, every day, from the same ranges.
- **Privacy browsers** with a built-in VPN (Opera, Brave, Edge Secure Network).
- **Security testing**, such as a penetration test or red team exercise. Check whether one was scheduled.

## Verdict

**Likely benign** if *all* of these are true:
- The user has used the same proxy provider before (step 4), or the IP belongs to your corporate egress or iCloud Private Relay (step 3)
- The proxy sessions use the user's known device and user agent, with MFA satisfied interactively (steps 5–6)
- Step 7 shows no persistence, mailbox changes or unusual data access from the proxy

**Likely malicious** if *any* of these are true:
- The IP is a Tor exit node and the user can't explain it
- The proxy sign-in used single-factor or legacy auth, or followed failed passwords
- The device or user agent on the proxy is new and unmanaged, or the session appears with a different user agent (step 6)
- Inbox rules, forwarding, MFA or device registrations, app consents, bulk downloads or sharing links came from the proxy IP (step 7)
- Other unrelated accounts used the same proxy IPs around the same time (step 8)

## Containment

1. [ ] **Revoke all sessions** (Entra ID → user → *Revoke sessions*), or disable the account. A password reset alone does not kill a stolen cookie.
2. [ ] **Reset the password**, and confirm the user as compromised in Entra ID Protection.
3. [ ] **Remove attacker-added MFA methods, devices and app consents** (step 7).
4. [ ] **Delete malicious inbox rules and forwarding**, and remove mailbox delegations (step 7).
5. [ ] **Block the proxy IPs** (Conditional Access named location or Defender indicators).
6. [ ] **Investigate every other account** found in step 8.
7. [ ] **Hardening:** a Conditional Access policy on sign-in risk (block or require MFA for medium and high), block Tor where the business allows, and register your corporate VPN/SSE ranges in Defender for Cloud Apps so real alerts stand out.
8. [ ] **Document the findings**: timeline, IOCs, root cause.

## Related detection rules

- None yet. A custom detection for this scenario is planned.

## Templates

- Closure: [closure-notes.md](../../templates/closure-notes.md)
- Escalation: [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- Report: [incident-report.md](../../templates/incident-report.md)
