# Playbook: Leaked Credentials (Single User)

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** *Leaked credentials* (Entra ID Protection user risk detection, `leakedCredentials`), *User at risk* with risk detail *Leaked credentials*, or a third-party / threat-intel report that one user's username and password are for sale or in a dump
**MITRE ATT&CK:** T1078.004 Valid Accounts: Cloud · T1589.001 Gather Victim Identity Information: Credentials · T1555.003 Credentials from Web Browsers · T1110.004 Credential Stuffing

---

## How the attack works

Credentials leak from a third-party breach, a phishing kit, or most often today an **infostealer** on a personal or work device that dumps saved browser passwords and cookies. Microsoft's leaked-credentials service finds the pair on paste sites, dark-web markets and stealer logs, and raises the detection **only if the leaked password matches the user's current password hash**. So this alert is an *offline* detection: it tells you a working password is out there, not that anyone has used it. Your job is to find out whether someone already has, and to make sure the leaked password stops working.

**What it looks like in the logs:**
- An Entra ID Protection alert with no IP, location or sign-in attached (offline detection), and user risk raised to **High**
- If unused: nothing else. Normal IPs, devices and MFA in the sign-in history
- If used: failed or blocked sign-ins where the **password was correct** (MFA required, CA block), single-factor or legacy-auth successes, then MFA registration, inbox rules or mail access from a new IP

## Before you start

Gather these values and fill them into the `let` lines of each query:

| Variable | Example |
|---|---|
| `user` | `user@domain.com` |
| `alertTime` | `datetime(2026-11-27 06:00:00)` (UTC) |
| `ips` | `dynamic(["x.x.x.x"])` (suspicious IPs from steps 4–5) |
| `knownIPs` | `dynamic(["y.y.y.y"])` (the user's normal IPs, optional) |

In the Entra admin center open **ID Protection → Risk detections**, filter on the user and detection type *Leaked credentials*, and note the **detection time** and **leak source / date** if shown. Advanced Hunting doesn't hold offline risk detection details. Check **Risky users** too: if the user is already *Remediated* or *Dismissed*, someone may have handled it.

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Alert scope | [01-alert-scope.kql](queries/01-alert-scope.kql) | The leaked-credentials alert, plus any other alert on the user in 30 days (unfamiliar sign-in, anonymous IP, spray, inbox rule) |
| 2 | User profile | [02-user-profile.kql](queries/02-user-profile.kql) | Privileged roles, hybrid vs cloud-only, job title, current user risk level |
| 3 | Password age | [03-password-age.kql](queries/03-password-age.kql) | When the password last changed, in Entra and on-prem AD. Older than the alert = the leaked password still works |
| 4 | Sign-in baseline | [04-signin-baseline.kql](queries/04-signin-baseline.kql) | Normal IPs, countries and devices, and IPs first seen in the last 7 days |
| 5 | Password tested? | [05-password-tested.kql](queries/05-password-tested.kql) | Attempts from unknown IPs, and whether the error code shows the password was **correct** (50074/50076/500121/53003) |
| 6 | Risky successes | [06-risky-successes.kql](queries/06-risky-successes.kql) | Single-factor, legacy-auth, CA notApplied, unmanaged or automation user-agent successes |
| 7 | Persistence | [07-persistence.kql](queries/07-persistence.kql) | New MFA methods, device registrations, app consents, password changes, especially from `ips` |
| 8 | Mailbox abuse | [08-mailbox-abuse.kql](queries/08-mailbox-abuse.kql) | Inbox rules, forwarding, delegation, mail read, file downloads, sharing links |
| 9 | Leak source | [09-leak-source-devices.kql](queries/09-leak-source-devices.kql) | Malware / credential-theft alerts on devices the user logs on to (infostealer) |
| 10 | Blast radius | [10-blast-radius.kql](queries/10-blast-radius.kql) | Other accounts tried from the same IPs, and which had a correct password |

**Then:** if step 6 shows an attacker sign-in, run the [impossible travel playbook](../impossible-travel/README.md) steps 4b–9 to scope the session. If step 8 shows inbox rules or payment emails, go to the [BEC playbook](../business-email-compromise/README.md). If step 9 finds an infostealer, investigate the device with the [suspicious PowerShell playbook](../suspicious-powershell/README.md) (ClickFix is a common delivery route) and treat session cookies as stolen ([AiTM playbook](../aitm-token-theft/README.md) step 3). If step 10 shows many accounts, switch to the [password spray playbook](../password-spray/README.md).

## Triage at a glance

| What you see | What it means | Action |
|---|---|---|
| Password changed **after** the leak was detected, no unknown sign-ins | The leaked password no longer works | Confirm, close as benign true positive, dismiss user risk |
| Password **older** than the alert, only normal IPs and devices | Valid password exposed, not yet used | Force a reset now, revoke sessions, close as true positive (no compromise) |
| Only `50126` (wrong password) from unknown IPs | Attacker has an old or mistyped password | Reset anyway, watch for repeats, check step 10 |
| `50074` / `50076` / `53003` from unknown IPs | Attacker has the **right** password, MFA or CA stopped them | Reset password and revoke sessions now, confirm the user's MFA methods are theirs |
| `500121` bursts, user says they got MFA prompts they didn't start | MFA fatigue attempt with the correct password | Reset, revoke, enable number matching, ask whether they approved any |
| Single-factor or legacy-auth success from a new IP | Account compromised | Escalate, contain immediately |
| New MFA method, device or inbox rule from the new IP | Compromise with persistence | Full containment, run BEC / impossible travel scoping |
| Infostealer alert on one of the user's devices | Leak source found, cookies likely stolen too | Isolate device, reset **all** passwords saved in that browser, revoke sessions |

## Field notes

- **The alert has no IP for a reason.** Leaked credentials is an offline detection: it fires when Microsoft finds the leak, not when someone signs in. Don't hunt for "the IP in the alert", build the IP list yourself from steps 4–5.
- **Microsoft already checked the password is current at detection time.** For hybrid users this depends on password hash sync. If the password changed between the leak and the detection, the alert wouldn't fire, so step 3 is about whether it changed *since*.
- **A failed sign-in can still prove the password works.** Error codes 50074, 50076, 500121, 53003, 50055 and 50144 only appear after the password was accepted. This is the most important signal in this playbook and is easy to dismiss as "it failed, so it's fine".
- **Leak date and detection date are different.** Stealer logs can sit for weeks before they're traded and indexed. Look back the full 30 days, not just around the alert time.
- **Self-service password reset clears the risk automatically** if the user has MFA and a CA risk policy forces a secure change. A user marked *Remediated* in Risky users usually means this happened; still check that no attacker sign-ins came before the reset.
- **Infostealers take cookies too.** If step 9 finds one, a password reset alone is not enough: revoke sessions and treat every site saved in that browser (personal accounts included) as exposed.
- **Contact the user through a channel other than their mailbox** (phone, Teams from a known device). Ask whether they reused this password elsewhere and whether they saved it in a personal browser.

## Common false positives

- **Password already changed** after the leak, by the user or by a risk-based CA policy (step 3).
- **Old breach, same password reused for years.** It's a real exposure, not a false positive, but usually no attacker activity: reset and close.
- **Test or service accounts** seeded into breach lists by security testing. Check with whoever owns the account.
- **Duplicate detections** for the same leak after the risk was dismissed without a password change. The detection fires again until the password changes.

## Verdict

**Likely benign (exposure only, no compromise)** if *all* of these are true:
- The password changed after the detection time (step 3), **or** it has been reset as part of this investigation
- No sign-ins from new IPs with a correct-password error code or a success (steps 5–6)
- No persistence, mailbox changes or unusual data access (steps 7–8)
- No other risk or identity alerts on the user (step 1)

**Likely malicious (account used by an attacker)** if *any* of these are true:
- Correct-password errors (50074, 50076, 500121, 53003) or successes from IPs the user doesn't recognise (step 5)
- A single-factor, legacy-auth or automation user-agent success from a new IP (step 6)
- MFA methods, devices, app consents, inbox rules or forwarding added from a suspicious IP (steps 7–8)
- The user received MFA prompts they didn't start
- An infostealer or credential-theft alert on a device the user uses (step 9)

## Containment

1. [ ] **Force a password reset** (not just "require change at next sign-in" if the attacker may sign in first). For hybrid users, reset in on-prem AD and confirm it syncs.
2. [ ] **Revoke all sessions** (Entra ID → user → *Revoke sessions*) so existing tokens and stolen cookies stop working.
3. [ ] **Confirm or dismiss user risk** in Entra ID Protection: *Confirm user compromised* if steps 5–8 show attacker activity, otherwise let the reset remediate it.
4. [ ] **Review MFA methods with the user** and remove any they don't recognise (step 7). Remove attacker devices and app consents.
5. [ ] **Remove malicious inbox rules, forwarding and delegations** (step 8).
6. [ ] **Block the attacker IPs** (Conditional Access named location or Defender indicators).
7. [ ] **Isolate and clean any infected device** from step 9, and tell the user to change every password saved in that browser, personal accounts included.
8. [ ] **Check every other account** from step 10.
9. [ ] **Hardening:** a user-risk Conditional Access policy (require secure password change on high risk), block legacy authentication, MFA number matching, and password protection with a custom banned list.
10. [ ] **Document the findings**: leak source, timeline, IOCs, root cause.

## Related detection rules

- [Legacy auth success](../../detections/legacy-auth-success.kql)
- [Password spray compromise](../../detections/password-spray-compromise.kql)
- [BEC high-risk inbox rule](../../detections/bec-suspicious-inbox-rule.kql)
- [BEC external forwarding](../../detections/bec-external-forwarding.kql)

## Templates

- Closure: [closure-notes.md](../../templates/closure-notes.md)
- Escalation: [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- Report: [incident-report.md](../../templates/incident-report.md)
