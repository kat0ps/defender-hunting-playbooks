# Simulate: Impossible travel

Safe test for the rule [`detections/sentinel/impossible-travel.yaml`](../../../detections/sentinel/impossible-travel.yaml). Run it **only in your own lab tenant** with a **test user**.

## Prerequisites
- The **Microsoft Entra ID** connector is sending `SigninLogs` and `AADNonInteractiveUserSignInLogs` (see [data-connectors.md](../../docs/data-connectors.md)), both tables are in `available_tables`, the rule is in `enabled_rules`, and `terraform apply` has run so the rule shows under **Sentinel → Analytics**.
- A **test user** (for example `labuser1@<tenant>.onmicrosoft.com`). Never use your admin or a real person's account.
- A reputable VPN with a server **at least 500 km away** (Europe or the US works from South Africa).

## Safe steps to trigger it
1. VPN **off**: sign in to <https://myapps.microsoft.com> as the test user. Note the time.
2. Sign out, connect the VPN to a far country, and confirm your public IP changed ("what is my IP").
3. **Within 1 hour** of step 1, sign in again as the same test user (complete MFA).
4. Disconnect the VPN.
5. Confirm both sign-ins in **Sentinel → Logs**:
   ```kql
   SigninLogs
   | where UserPrincipalName == "labuser1@<tenant>.onmicrosoft.com"
   | project TimeGenerated, IPAddress, tostring(LocationDetails.countryOrRegion), ResultType
   ```

This rule runs **once a day**, so either deploy it right after the two sign-ins (a new rule's first run starts soon after creation) or wait for the next daily run.

## Expected alert
Incident **"Impossible travel: successful sign-ins faster than 900 km/h apart"** (Medium). Account entity = the test user; IP entities = your home IP (`FromIP`) and the VPN IP (`ToIP`). Results show `DistanceKm`, `HoursBetween`, `SpeedKmh`.

## Evidence checklist — save to `lab/evidence/impossible-travel/`
- [ ] `01-analytics-rule.png` — the rule under Sentinel → Analytics (Enabled).
- [ ] `02-two-signins-logs.png` — the Logs query showing both sign-ins from different countries.
- [ ] `03-incident.png` — the incident, with severity and the entities.
- [ ] `04-results.png` — the rule result row (DistanceKm / SpeedKmh).
- [ ] `notes.md` — what you did, the time, and any tuning (for example adding your VPN's egress range to `excludedRanges`).
