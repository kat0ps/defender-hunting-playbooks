# Playbook: Password Spray / Brute Force

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** *Password spray*, *Unfamiliar sign-in properties*, Entra ID Smart Lockout spikes, many users reporting lockouts
**MITRE ATT&CK:** T1110.003 Password Spraying · T1110.001 Password Guessing · T1110.004 Credential Stuffing · T1078.004 Valid Accounts: Cloud

---

## Key error codes

| Code | Meaning | Why it matters |
|---|---|---|
| **50126** | Invalid username or password | The core spray signal |
| **50053** | Account locked (Smart Lockout) | Too many attempts on one account |
| **50034** | User doesn't exist | Username enumeration or a bad target list |
| **50057** | Account disabled | The attacker is using an old user list |
| **50055** | Password expired | Valid password, just expired |
| **50074 / 50076** | MFA required | ⚠️ **The password was correct.** Only MFA stopped the attacker |
| **500121** | MFA failed or denied | ⚠️ Password correct, MFA attempted (possible fatigue) |
| **53003** | Blocked by Conditional Access | ⚠️ Password correct, CA stopped it |
| **0** | Success | 🚨 The attacker got in |

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Spray by IP | [01-spray-by-ip.kql](queries/01-spray-by-ip.kql) | One IP failing against many users (classic spray) |
| 2 | Success after spray | [02-success-after-spray.kql](queries/02-success-after-spray.kql) | 🚨 Any user who **successfully** signed in from a spraying IP |
| 3 | Password correct, MFA/CA stopped it | [03-password-correct-blocked.kql](queries/03-password-correct-blocked.kql) | ⚠️ Users whose password the attacker **knows**, even though they didn't get in |
| 4 | Distributed (low and slow) | [04-distributed-per-user.kql](queries/04-distributed-per-user.kql) | One user failing from many IPs (rotating proxies, botnets) |
| 5 | Spray by user agent | [05-spray-by-useragent.kql](queries/05-spray-by-useragent.kql) | Distributed spray tied together by a shared user agent or tool |
| 6 | Legacy authentication | [06-legacy-auth.kql](queries/06-legacy-auth.kql) | IMAP/POP/SMTP/ActiveSync attempts, which bypass MFA if legacy auth is still allowed |

## Common false positives

- **A user with an old password saved on a phone or mail app**, retrying constantly. This is one user, one or two IPs, a steady rate, and the same device.
- **A misconfigured service account or scanner** hitting many accounts from an internal or known IP.
- **Shared NAT or office egress IPs**, where many users mistyping passwords show up as one IP. Check that the IP isn't your own office.

## Verdict

- **Spray, no impact:** only 50126/50034/50053 errors, no successes, no MFA-required results. Block the IP and monitor.
- **Spray, passwords exposed:** 50074/50076/500121/53003 results for some users. Their passwords are known, so reset them.
- **Spray, compromise:** successful sign-ins (step 2). Treat as account compromise and run the [impossible travel playbook](../impossible-travel/README.md) steps 3–9 for each user.

## Containment

1. [ ] **Block the spraying IPs and ranges** (Conditional Access named location, or the firewall for ADFS).
2. [ ] **Reset passwords** for every user in step 2 and step 3.
3. [ ] **Revoke sessions** for users who successfully signed in, and investigate their activity.
4. [ ] **Block legacy authentication** with Conditional Access if step 6 shows attempts.
5. [ ] **Check MFA coverage:** users without MFA registered are the most exposed.
6. [ ] **Hardening:** Entra Password Protection with a custom banned list (company name, city, season+year), and a tuned Smart Lockout threshold.

## Related detection rules

- [A spraying IP (failures against 10+ users) got a correct password: signed in, or was only stopped by MFA/CA](../../detections/password-spray-compromise.kql)
- [Successful sign-in over a legacy authentication protocol (cannot enforce MFA)](../../detections/legacy-auth-success.kql)

## Templates

- [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- [closure-notes.md](../../templates/closure-notes.md)
- [incident-report.md](../../templates/incident-report.md)
