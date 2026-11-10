# Playbook: Business Email Compromise (BEC)

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** *Suspicious inbox manipulation rule*, *Suspicious email forwarding activity*, *BEC financial fraud*, a supplier or customer reporting changed banking details, an unexpected payment request
**MITRE ATT&CK:** T1586.002 Compromise Accounts: Email · T1114.003 Email Forwarding Rule · T1564.008 Email Hiding Rules · T1534 Internal Spearphishing · T1656 Impersonation

---

## The BEC pattern

1. **Access:** the account is compromised (phishing, AiTM or password spray), or the attacker impersonates someone from outside.
2. **Hide:** inbox rules that move or delete replies from the victim's finance contacts, often with names like `.`, `..` or `,,`.
3. **Watch:** the attacker reads mail quietly (`MailItemsAccessed`) to learn about invoices and payment cycles.
4. **Strike:** they reply inside a real thread, or send "updated banking details", "urgent EFT" or "proof of payment" emails.
5. **Cover tracks:** they delete sent items and replies.

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Suspicious inbox rules | [01-suspicious-inbox-rules.kql](queries/01-suspicious-inbox-rules.kql) | Rules that forward, delete, mark as read, hide in RSS/Archive, use finance keywords, or have very short names. Scored by risk. |
| 2 | Mailbox forwarding and transport rules | [02-mailbox-forwarding.kql](queries/02-mailbox-forwarding.kql) | `ForwardingSmtpAddress` set on a mailbox, or transport rules that redirect or BCC mail |
| 3 | Finance-themed internal email | [03-finance-themed-internal-email.kql](queries/03-finance-themed-internal-email.kql) | Internal accounts suddenly sending invoice, payment or banking emails to many recipients |
| 4 | Inbound bank change requests | [04-bank-change-requests-inbound.kql](queries/04-bank-change-requests-inbound.kql) | Banking or payment emails from sender domains never seen before (lookalike or new domains) |
| 5 | Executive impersonation | [05-display-name-impersonation.kql](queries/05-display-name-impersonation.kql) | External email using a VIP's display name |
| 6 | Mailbox activity from new IPs | [06-mail-access-new-ip.kql](queries/06-mail-access-new-ip.kql) | Mail read, sent or deleted from IPs not in the user's 30-day baseline |

**Then:** for every compromised account, run the [impossible travel playbook](../impossible-travel/README.md) steps 2–5 to find how and when access was gained.

## Common false positives

- **Users' own organising rules** (moving newsletters, auto-filing supplier invoices). These usually have descriptive names and were created from known IPs and devices.
- **Approved forwarding** to a personal assistant or a shared finance mailbox.
- **Normal finance team email.** Step 3 will always flag the AP/AR team. Look for **unusual senders** or a sudden change in volume.

## Verdict

**Likely BEC** if *any* of these are true:
- An inbox rule hides or deletes mail from finance contacts, or has a meaningless short name, and was created from an unfamiliar IP
- External forwarding was set without a business reason
- A banking-details change came from a new or lookalike domain, or from an internal account that was signing in from an unusual location

## Containment

1. [ ] **Contact finance immediately:** hold or recall any payment made to changed banking details. Time matters most here.
2. [ ] **Revoke sessions and reset the password** for the compromised mailbox.
3. [ ] **Delete malicious inbox rules**, remove forwarding, and review delegates and mailbox permissions.
4. [ ] **Find and purge** fraudulent emails the attacker sent, and notify the recipients (customers and suppliers).
5. [ ] **Block** lookalike sender domains and any external forwarding addresses.
6. [ ] **Hardening:** disable automatic external forwarding (outbound spam policy), enable impersonation protection for VIPs, and require phone verification for any banking-details change.
