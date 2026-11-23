# Playbook: Phishing Email Triage

**Platform:** Microsoft Defender XDR Advanced Hunting (Defender for Office 365 + Defender for Endpoint)
**Triggers:** User-reported phish, *Email messages containing malicious URL removed after delivery*, *A potentially malicious URL click was detected*, *Email reported by user as malware or phish*
**MITRE ATT&CK:** T1566.001 Spearphishing Attachment · T1566.002 Spearphishing Link · T1204.001 User Execution: Malicious Link · T1204.002 User Execution: Malicious File

---

> **Starting from a user report?** Run the [user-reported email playbook](../user-reported-email/README.md) first for a quick benign-or-malicious verdict, then come back here if it's malicious.

## The four questions

1. **What is it?** Sender, authentication results, URLs, attachments
2. **How big is it?** Every recipient of the same campaign
3. **Who interacted?** Who clicked, who opened or ran the attachment
4. **Is it cleaned up?** Is the email still sitting in any mailbox?

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Find the email | [01-find-email.kql](queries/01-find-email.kql) | NetworkMessageId, sender, SPF/DKIM/DMARC/CompAuth as separate columns, From vs MailFrom mismatch, delivery action and current location |
| 2 | URLs and attachments | [02-email-artifacts.kql](queries/02-email-artifacts.kql) | URL domains and attachment hashes to pivot on, with `RiskFlags` for double extensions, risky file types, shorteners and raw-IP links |
| 3 | Campaign scope | [03-campaign-scope.kql](queries/03-campaign-scope.kql) | Every recipient of the same sender, subject, URL domain or attachment hash |
| 4 | Who clicked | [04-who-clicked.kql](queries/04-who-clicked.kql) | `ClickAllowed` / `IsClickedThrough = true` means the user reached the site |
| 5 | Attachment execution | [05-attachment-execution.kql](queries/05-attachment-execution.kql) | The attachment saved to disk or executed on an endpoint (paste the NetworkMessageId to check every attachment at once) |
| 6 | Remediation status | [06-remediation-status.kql](queries/06-remediation-status.kql) | Copies still in Inbox or Junk, and whether ZAP or manual remediation ran |

**Then:**
- **Users who clicked a credential-harvesting link:** run the [AiTM playbook](../aitm-token-theft/README.md) step 2 to check for a sign-in from a new IP straight after the click.
- **Users who ran an attachment:** run the [suspicious PowerShell playbook](../suspicious-powershell/README.md) step 7 (device timeline) on their device.

## Reading the authentication results (step 1)

Step 1 splits `AuthenticationDetails` into `SPF`, `DKIM`, `DMARC` and `CompAuth` columns:
- **`FromMailFromMismatch = true`:** the visible From domain differs from the envelope (MailFrom) domain. Common for bulk mail services, but combined with a DMARC fail it points to spoofing.
- **DMARC fail or CompAuth fail** from a domain that looks like a known brand or partner suggests spoofing.
- **All checks pass from a newly registered or lookalike domain:** the attacker owns the domain. Passing checks don't make it safe.
- **All checks pass from a real partner's domain:** that partner may be compromised (vendor email compromise). Warn them.

## Reading the artifacts (step 2)

- **`RiskFlags` is a prompt, not a verdict.** Look up every SHA256 and URL domain in VirusTotal or your threat intel.
- **Double extension** (`invoice.pdf.exe`) is a classic lure; versioned names like `report.v2.pdf` will also trigger it.
- **HTML, SVG, ISO, LNK and OneNote attachments** are common phishing and malware loaders and rarely legitimate from outside senders.
- **Lookalike domains** (`micros0ft-login.com`) aren't flagged automatically, so read the URL domains by eye.

## Common false positives

- **Marketing or newsletter mail** reported by users. The authentication checks pass, the sender is known, and the links go to legitimate domains.
- **Security awareness simulations.** Check with whoever runs your phishing simulations before raising an incident.
- **Safe Links detonation clicks.** These are scans, not user clicks.

## Verdict

- **Malicious, no interaction:** delivered but nobody clicked or opened it. Purge it and block the sender, domain and URL.
- **Malicious, clicked:** someone clicked a credential-harvesting link. Treat each clicker as a possible compromise (AiTM playbook).
- **Malicious, executed:** an attachment ran on an endpoint. Isolate the device and investigate it.

## Containment

1. [ ] **Purge every copy** (Threat Explorer → Soft delete, or Take actions from the hunting results).
2. [ ] **Block** the sender address and domain, URLs and file hashes (Tenant Allow/Block List and Defender indicators).
3. [ ] **For clickers:** check for sign-ins straight after the click, and revoke sessions and reset passwords if found.
4. [ ] **For executed attachments:** isolate the device, collect an investigation package, and run a full scan.
5. [ ] **Notify users** who received it, and thank the reporter.
6. [ ] **If a partner domain was the sender**, warn that partner that they may be compromised.

## Related detection rules

- [User reached a URL that Safe Links flagged, clicked through a warning, or came from an email later removed by ZAP](../../detections/phishing-malicious-url-click.kql)

## Templates

- [phishing-user-notification-email.md](../../templates/phishing-user-notification-email.md)
- [closure-notes.md](../../templates/closure-notes.md)
- [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
- [incident-report.md](../../templates/incident-report.md)
