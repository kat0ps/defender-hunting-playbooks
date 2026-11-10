# Template: Alert / Incident Closure Notes

Short notes to paste into the incident's comment or classification field, or into the ticket. Pick the matching version.

---

## False positive

```
Classification: False positive
Alert: <alert title> | <date/time>
Entity: <user / device / email>

Summary: <one line on why the alert fired>.
Investigation: <what was checked, e.g. "Sign-ins reviewed (30d baseline), mailbox rules, outbound email, file access">.
Finding: <why it is not malicious, e.g. "Activity originated from the corporate VPN egress IP 203.0.113.10">.
Action: No action required. <Tuning: "Added 203.0.113.0/24 to excludedRanges in impossible-travel detection" / none>.
Playbook: <playbook name>
```

## Benign true positive (real activity, but expected)

```
Classification: True positive – benign / informational (expected activity)
Alert: <alert title> | <date/time>
Entity: <user / device / email>

Summary: The alert correctly detected <activity>, which was confirmed as legitimate.
Confirmation: <who confirmed and how, e.g. "Manager <name> confirmed by email on <date> that the user is travelling in NL/TR (leave 8–20 Nov)">.
Investigation: <checks performed>. No malicious activity found (<e.g. no inbox rules, forwarding, data access or phishing>).
Action: Closed. <Recommendation if any, e.g. "Recommended CA policy for unmanaged mobile devices">.
Playbook: <playbook name>
```

## True positive (malicious)

```
Classification: True positive – malicious
Alert: <alert title> | <date/time>
Entity: <user / device / email>

Summary: <one line, e.g. "Account compromised via AiTM phishing; attacker created inbox rule and sent internal phish">.
Root cause: <how access was gained>.
Scope: <users / devices / mailboxes affected, time window>.
Containment: <actions + times, e.g. "Sessions revoked 10:42, password reset 10:45, inbox rule removed 10:50, email purged from 14 mailboxes 11:05, IPs blocked">.
IOCs: <IPs, domains, hashes>.
Follow-up: <open items, e.g. "Client to confirm no payments made to changed bank details">.
Report: <link to incident report>
Playbook: <playbook name>
```
