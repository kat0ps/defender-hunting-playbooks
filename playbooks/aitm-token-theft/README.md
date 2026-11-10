# Playbook: AiTM Phishing / Session Token Theft

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** *Possible AiTM phishing attempt*, *Stolen session cookie was used*, *Suspicious sign-in after phishing click*, user reports entering credentials on a phishing page
**MITRE ATT&CK:** T1566.002 Spearphishing Link · T1557 Adversary-in-the-Middle · T1539 Steal Web Session Cookie · T1550.004 Web Session Cookie · T1098.005 Device Registration · T1564.008 Email Hiding Rules

---

## How AiTM works (and why MFA doesn't stop it)

The victim clicks a phishing link that loads a **reverse proxy** in front of the real Microsoft sign-in page. The victim types their password and completes MFA as normal. The proxy passes everything through to Microsoft and **captures the session cookie** Microsoft returns. The attacker then replays that cookie from their own infrastructure, so they're signed in with MFA already satisfied.

**What it looks like in the logs:**
- An email link click, followed within minutes by a successful sign-in from an IP the user has never used (the proxy server)
- Proxy kits often sign in with automation user agents (`axios`, `node-fetch`, `python-requests`)
- The same session then shows up from other IPs, countries or user agents (cookie replay)
- Within hours: new MFA method, new device registration, inbox rules hiding replies, internal phishing

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Automation user agents | [01-suspicious-signin-useragents.kql](queries/01-suspicious-signin-useragents.kql) | Successful sign-ins from HTTP libraries such as `axios` or `node-fetch`. Real users don't sign in with these. |
| 2 | Click, then new-IP sign-in | [02-click-then-new-ip-signin.kql](queries/02-click-then-new-ip-signin.kql) | A user clicked an email link, then signed in from a never-seen IP within 30 minutes |
| 3 | Session replay (tenant-wide) | [03-session-replay-tenant.kql](queries/03-session-replay-tenant.kql) | One `SessionId` across several countries, especially with the user agent changing mid-session |
| 4 | Post-sign-in persistence | [04-post-signin-persistence.kql](queries/04-post-signin-persistence.kql) | MFA registration, device registration, inbox rules or app consent within 6 hours of a new-IP sign-in |
| 5 | Related alerts | [05-aitm-alerts.kql](queries/05-aitm-alerts.kql) | Defender's built-in AiTM and stolen-cookie alerts and their entities |

**Then:** for each confirmed user, run the [impossible travel playbook](../impossible-travel/README.md) steps 2–9 to scope their activity, and the [phishing triage playbook](../phishing-triage/README.md) to find every recipient of the lure.

## Common false positives

- **Legitimate automation:** service accounts or scripts using `python-requests` or similar. These are usually the same IP and the same account every day.
- **First sign-in from a new home, hotel or mobile IP** shortly after reading email. Check whether the IP's ISP is residential or mobile in the user's own country.
- **Security tools detonating links** (sandbox clicks). Their IPs belong to the security vendor and the clicks don't come from the user's device.

## Verdict

**Likely AiTM** if *any* of these are true:
- A successful sign-in came from an automation user agent on a hosting or VPN IP
- A click on a newly registered or unknown domain was followed by a new-IP sign-in within minutes
- The session was replayed with a changed user agent or from a different country
- An MFA method or device was registered, or an inbox rule created, shortly after

## Containment

1. [ ] **Revoke all sessions.** A password reset alone does **not** invalidate a stolen cookie.
2. [ ] **Reset the password**, and confirm the user as compromised in Entra ID Protection.
3. [ ] **Remove attacker-registered MFA methods and devices.**
4. [ ] **Delete malicious inbox rules**, and check for internal phishing sent from the account.
5. [ ] **Block the phishing domain and proxy IPs** (Defender indicators, Tenant Allow/Block List).
6. [ ] **Purge the phishing email** from every mailbox (phishing triage playbook, step 6).
7. [ ] **Hardening:** phishing-resistant MFA (FIDO2/passkeys, Windows Hello), Conditional Access requiring compliant devices, and Token Protection where supported.

## Related detection rules

- [Successful sign-in from an HTTP automation user agent (AiTM proxy / token tooling)](../../detections/aitm-automation-useragent-signin.kql)
- [Email link click followed within 30 minutes by a successful sign-in from a never-seen IP](../../detections/aitm-click-then-new-ip-signin.kql)
- [One sign-in session used from more than one country AND more than one user agent (session cookie replay)](../../detections/aitm-session-replay-useragent-change.kql)

## Templates

- [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- [closure-notes.md](../../templates/closure-notes.md)
- [incident-report.md](../../templates/incident-report.md)
