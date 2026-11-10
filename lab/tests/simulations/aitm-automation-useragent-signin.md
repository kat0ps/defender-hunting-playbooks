# Simulate: AiTM automation user-agent sign-in

Safe test for [`detections/sentinel/aitm-automation-useragent-signin.yaml`](../../../detections/sentinel/aitm-automation-useragent-signin.yaml). **Lab tenant + test user only.**

The rule looks for a *successful* sign-in whose user agent is an HTTP library (curl, python-requests and similar). You reproduce that benignly by signing the test user in from a command-line HTTP client — no proxy, no stolen tokens.

## Prerequisites
- Entra ID connector sending `SigninLogs` + `AADNonInteractiveUserSignInLogs`; tables in `available_tables`; rule deployed.
- A **test user** whose sign-in can succeed **without MFA** for a few minutes. If a Conditional Access policy forces MFA, temporarily exclude the test user, then **put it back immediately after**. (A script can't complete MFA, so the sign-in would otherwise fail and the rule — which only fires on success — wouldn't trigger.)
- `curl` (built into Windows 11 and macOS).

## Safe steps to trigger it
1. In the lab tenant, make sure the test user can do a plain password sign-in to a first-party app (for example the Microsoft Graph CLI or Azure CLI test app).
2. From a terminal, sign the **test user** in with a tool that sends a library user agent — the simplest is Azure CLI, which identifies itself as `python-requests`:
   ```bash
   az login -u labuser1@<tenant>.onmicrosoft.com -p '<test-user-password>'
   az logout
   ```
   (Using a dedicated CLI avoids writing any credential-replay script of your own.)
3. Re-enable MFA for the test user if you disabled it.
4. Confirm the sign-in's user agent in **Logs**:
   ```kql
   union SigninLogs, AADNonInteractiveUserSignInLogs
   | where UserPrincipalName == "labuser1@<tenant>.onmicrosoft.com" and ResultType == "0"
   | project TimeGenerated, UserAgent, AppDisplayName, IPAddress
   ```

Runs hourly — allow up to ~90 minutes.

## Expected alert
Incident **"AiTM: successful sign-in from an HTTP automation user agent"** (High). Account = test user; IP = the client IP. The result's `UserAgent` contains `python-requests` (or whichever library tool you used).

## Evidence checklist — `lab/evidence/aitm-automation-useragent-signin/`
- [ ] `01-signin-useragent-logs.png` — Logs query showing the library user agent.
- [ ] `02-incident.png` — the incident with the Account/IP entities.
- [ ] `notes.md` — the tool you used, whether you toggled MFA, and any service accounts you'd add to `excludedAccounts`.
