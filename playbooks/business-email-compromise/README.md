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

### Delayed or altered payment email

Use steps 7–10 when an invoice or payment email reached the client hours late, or the client paid a different amount or account than the one you sent.

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 7 | Trace the outbound email | [07-trace-outbound-payment-email.kql](queries/07-trace-outbound-payment-email.kql) | More than one version sent to the client, a version sent from a new IP or user agent, or a long gap (`SendToMailFlowMins`) between the mailbox Send and mail flow |
| 8 | Compare attachment hashes | [08-attachment-hash-compare.kql](queries/08-attachment-hash-compare.kql) | The same file name with more than one SHA256 (`HashesForThisFileName > 1`), or a hash that doesn't match the file the client received |
| 9 | Message tampering in the mailbox | [09-message-tampering.kql](queries/09-message-tampering.kql) | Drafts or sent items edited (`Update`), the original moved or deleted, Sent Items cleaned up, especially from an unfamiliar IP |
| 10 | Lookalike domains in the thread | [10-thread-lookalike-domains.kql](queries/10-thread-lookalike-domains.kql) | Rows where `Side = OTHER`: a third domain replying in the thread, usually a lookalike of yours or the client's |

**Ask the client for the email as they received it** (the .eml file or full headers) before you finish. The headers settle where the delay happened and whether the email came from you:

| Header | What to check |
|---|---|
| `Received:` lines | Read bottom to top. The gap between two timestamps shows which hop held the email. |
| `Message-ID` | Must match `InternetMessageId` from step 7. No match = not the email you sent. |
| `From` / `Return-Path` / `Reply-To` | Must be your real domain. A lookalike or a different Reply-To = spoofed or hijacked thread. |
| `Authentication-Results` | SPF, DKIM and DMARC should pass for your domain. |

**Then:** for every compromised account, run the [impossible travel playbook](../impossible-travel/README.md) steps 2–5 to find how and when access was gained.

## Triage at a glance: delayed or altered payment email

| What you see | What it means | Action |
|---|---|---|
| One version in step 7, same Message-ID and hash as the client's copy, delay only in the client's `Received:` hops | Your side looks clean; the delay or change happened after delivery | Ask the client's IT to investigate their mailbox for rules and sign-ins |
| Two versions in step 7, or a different SHA256 in step 8 | The email was re-sent with a changed attachment from your tenant | Treat the sender's account as compromised; run steps 1–6 and the impossible travel playbook |
| Step 9 shows `Update` or a delete of the email from an unfamiliar IP | Attacker edited or hid the original in the user's mailbox | Contain the account now, then scope with step 6 |
| The client's copy has a different Message-ID or From domain, and step 10 shows `Side = OTHER` | Lookalike domain hijacked the thread; your email may never have been altered | Block the domain, tell the client in writing and by phone, check how the attacker learned about the thread (either side could be compromised) |

## Common false positives

- **Users' own organising rules** (moving newsletters, auto-filing supplier invoices). These usually have descriptive names and were created from known IPs and devices.
- **Approved forwarding** to a personal assistant or a shared finance mailbox.
- **Normal finance team email.** Step 3 will always flag the AP/AR team. Look for **unusual senders** or a sudden change in volume.
- **Legitimate re-sends.** Users often re-send an invoice after correcting it. In step 7, a second version sent from the user's usual IP and device, followed by the user confirming the correction, is benign.
- **Delays outside your tenant.** Greylisting, a slow client mail gateway or a client quarantine can hold mail for hours. The client's `Received:` headers show this as a gap after your outbound server.

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

## Related detection rules

- [High-risk inbox rule (forward/delete/hide + finance keywords or meaningless short name)](../../detections/bec-suspicious-inbox-rule.kql)
- [Mail forwarded or redirected to an external domain (mailbox setting, inbox rule or transport rule)](../../detections/bec-external-forwarding.kql)
- [External email delivered using an executive's display name (CEO/CFO fraud)](../../detections/bec-vip-impersonation.kql)

## Templates

- [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- [closure-notes.md](../../templates/closure-notes.md)
- [incident-report.md](../../templates/incident-report.md)
