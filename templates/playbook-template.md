# Playbook: <Scenario name>

**Platform:** Microsoft Defender XDR Advanced Hunting
**Triggers:** <alert titles / detection rules / user reports>
**MITRE ATT&CK:** <T####.### Technique · T####.### Technique>

---

## How the attack works

<Two to four sentences on the attacker's goal and steps, and what that looks like in the logs.>

## Before you start

| Variable | Example |
|---|---|
| `user` | `user@domain.com` |
| `alertTime` | `datetime(2026-01-01 08:00:00)` |

<Checks to do first, e.g. look at the incident's automated investigation, confirm it isn't a simulation.>

---

## Investigation steps

| # | Step | Query | What you're looking for |
|---|---|---|---|
| 1 | <Step> | [01-<name>.kql](queries/01-<name>.kql) | <Signal> |
| 2 | <Step> | [02-<name>.kql](queries/02-<name>.kql) | <Signal> |

**Then:** <handoffs to other playbooks>

## Triage at a glance

| What you see | What it means | Action |
|---|---|---|
| <Observation> | <Interpretation> | <Next step> |

## Field notes

- <Lessons learned from real cases: quirks in the data, misleading signals>

## Common false positives

- <Benign cause and how to recognise it>

## Verdict

**Likely benign** if *all* of these are true:
- <Condition>

**Likely malicious** if *any* of these are true:
- <Condition>

## Containment

1. [ ] <Action>
2. [ ] <Action>

## Related detection rules

- [<Rule name>](../../detections/<rule>.kql)

## Templates

- Closure: [closure-notes.md](../../templates/closure-notes.md)
- Escalation: [escalation-compromise-email.md](../../templates/escalation-compromise-email.md)
