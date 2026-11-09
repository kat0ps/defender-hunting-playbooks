# Template: Impossible travel – request user travel confirmation

**Subject:** Security alert – please confirm travel for <User Name> (Impossible travel activity)

Hi <Name>,

We're investigating a Medium severity **Impossible travel activity** alert raised by Microsoft Defender for Cloud Apps for **<user UPN>** on **<date/time>**. We need your help to confirm whether the user is travelling before we close it or escalate.

**What triggered the alert**
<What activity, from which IP/country, then which IP/country, and how many minutes apart.>

**What we found**
- **Locations:** <timeline of countries/cities and IPs with first/last seen>
- **Device:** <device/user agent, managed or not, MFA status>
- **Account changes:** <password changes, MFA/device registration, with dates>
- **Post-sign-in activity:** <mailbox rules, forwarding, file access, outbound email: findings or "none found">
- **Other accounts:** <whether other users signed in from the same IPs>

**Our assessment**
<Benign travel vs compromise indicators, and what is still unconfirmed.>

**Please confirm**
1. Is <user> currently travelling or on leave? If so, where and on which dates?
2. Does <user> use a VPN, and/or a travel or foreign SIM/eSIM?
3. Does <user> use a <device model> phone?
4. Were the <date> password and MFA/device changes made by the user or by IT/helpdesk?

**Next steps**
- **If confirmed:** we'll close the alert as benign (user travel).
- **If not confirmed, or if we don't hear back by <time>:** we recommend revoking sessions, resetting the password, reviewing MFA methods and blocking the IPs.

**Additional recommendation**
<e.g. Conditional Access gap observed.>

Kind regards,
<Name>
<Team>
