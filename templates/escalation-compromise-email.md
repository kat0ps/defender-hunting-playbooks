# Template: Escalation – Confirmed or Suspected Compromise

Use this when a playbook verdict is **malicious** and the client needs to act or approve containment now.

**Subject:** URGENT – Security incident: <compromised account / malicious activity> – <User Name or Device>

Hi <Name>,

We've identified a **<High/Critical> severity security incident** affecting **<user UPN / device name>** and need your urgent attention.

**What happened**
<One or two sentences, e.g. "The account signed in from an attacker-controlled IP after the user entered their credentials on a phishing page. The attacker then created a rule to hide incoming emails.">

**Key findings**
- <e.g. Sign-in from 203.0.113.50 (Netherlands, hosting provider) at 09:14, 6 minutes after a phishing link click>
- <e.g. Inbox rule ".." created to delete emails containing "invoice" and "payment">
- <e.g. 23 phishing emails sent from the account to internal staff>
- <e.g. No evidence of file downloads>

**Actions we've taken**
- <e.g. Revoked all active sessions at 10:42>
- <e.g. Removed the malicious inbox rule>
- <e.g. Purged the phishing emails from all mailboxes>

**Actions needed from you**
1. <e.g. Approve a password reset and MFA re-registration for the user>
2. <e.g. Contact the user by phone (not email) to confirm whether they entered credentials>
3. <e.g. Ask Finance to check for any payments or banking-detail changes since <date>>

**Our recommendation**
<e.g. Keep the account disabled until the user re-registers MFA in person with IT.>

We'll keep you updated as the investigation continues. Please reply or call <phone> as soon as possible.

Kind regards,
<Name>
<Team / SOC> | <phone>
