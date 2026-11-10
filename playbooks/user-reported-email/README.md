# Playbook: User-Reported Email (M365 Suspicious User Submission)

**Platform:** Microsoft Defender XDR Advanced Hunting (Defender for Office 365)
**Triggers:** *Email reported by user as malware or phish*, *Email reported by user as junk/not junk*, submissions from the Outlook **Report** button
**MITRE ATT&CK:** T1566.001 Spearphishing Attachment · T1566.002 Spearphishing Link · T1656 Impersonation

---

## Goal

Decide quickly whether a reported email is **benign** (close it and give the reporter feedback) or **malicious** (scope, purge and check who interacted). Most user reports are marketing or legitimate email, so this playbook is built for fast, consistent closure.

---

## Before you start

- Open the incident and check the **Investigation** tab. Defender's automated investigation (AIR) often runs on user reports and may already have a verdict, or may have pending actions waiting for approval.
- Check with whoever runs **attack simulation training**. Simulation emails reported by users are a success, not an incident.

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | Reported email summary | [01-reported-email-summary.kql](queries/01-reported-email-summary.kql) | For each report: sender, authentication results, delivery, link domains, attachments, campaign size and who clicked, all in one row |
| 2 | All user submissions | [02-all-user-submissions.kql](queries/02-all-user-submissions.kql) | Every Report-button submission, including ones that didn't raise an alert |
| 3 | Similar reports | [03-similar-reports.kql](queries/03-similar-reports.kql) | The same sender or subject reported by several users, which suggests an active campaign |
| 4 | Sender reputation | [04-sender-reputation.kql](queries/04-sender-reputation.kql) | Is the sender domain new or established? Email volume, previous threat verdicts, DMARC failures |

**If malicious, continue with the [phishing triage playbook](../phishing-triage/README.md):**
- Step 3: full campaign scope
- Step 4: who clicked
- Step 5: whether the attachment ran
- Step 6: what still needs purging

## Triage at a glance

| What you see | What it means | Action |
|---|---|---|
| Authentication checks pass, sender seen for months, legitimate link domains, no clicks | Marketing, newsletter or normal business email | **Close as a false positive.** Mark "Not junk" or "No threats found" and notify the reporter |
| Sender known, but the user just doesn't want it | Spam or graymail | Mark as junk. Users can block the sender themselves |
| DMARC or CompAuth fail, a brand or partner lookalike, or a sender domain seen for the first time | Phishing or spoofing | **Malicious.** Go to phishing triage steps 3–6 |
| A real partner domain with all checks passing, but an unusual request (banking change, invoice link) | Possible vendor email compromise | **Malicious.** Run the [BEC playbook](../business-email-compromise/README.md) and warn the partner |
| **CampaignRecipients** greater than 1, or several reports of the same email (step 3) | An active campaign | Purge it from every mailbox |
| **Clickers** has names | Users reached the site | Run [AiTM playbook](../aitm-token-theft/README.md) step 2 for each clicker |
| Attachment hashes present | A possible malware payload | Run phishing triage step 5, then the [PowerShell playbook](../suspicious-powershell/README.md) step 7 if it ran |

## Common false positives

- **Newsletters, marketing and notification emails** (DocuSign, Microsoft, delivery services) that are genuine. Check the authentication results and the real link domains.
- **Attack simulation emails.** Confirm against the simulation schedule.
- **Internal emails that look unusual** (an HR announcement, an IT password expiry notice). Confirm with the sending team.

## Closing the report

1. [ ] In **Submissions → User reported**, select the email and choose **Mark as and notify** (*No threats found*, *Spam* or *Phishing/Malware*) so the reporter gets feedback.
2. [ ] Classify the alert or incident: *False positive*, *True positive* or *Informational, expected activity* (simulation).
3. [ ] If malicious: purge every copy, block the sender, domain, URLs and hashes in the **Tenant Allow/Block List**, and check the clickers.
4. [ ] If a legitimate email was blocked or junked: submit it to Microsoft as *Should not have been blocked*.
5. [ ] Thank the reporter. Positive feedback keeps people reporting.
