# Defender XDR Hunting Playbooks

Investigation playbooks and KQL queries for **Microsoft Defender XDR Advanced Hunting**.

Each playbook walks through an investigation from alert to verdict to containment, with ready-to-paste queries.

> **Table note:** Queries use `EntraIdSignInEvents`. If your tenant doesn't have it yet, swap in `AADSignInEventsBeta`, which has the same columns.
> **Retention:** Advanced Hunting keeps 30 days of data, so keep lookbacks at or under `30d`.

## Playbooks

| Playbook | Use when | Queries |
|---|---|---|
| [Impossible travel / account compromise](playbooks/impossible-travel/README.md) | An Atypical travel / Impossible travel alert fires, or you suspect a compromised Entra ID account | [queries](playbooks/impossible-travel/queries) |

## Detections

| Detection | Description |
|---|---|
| [Impossible travel](detections/impossible-travel.kql) | Successful sign-ins from two locations that are too far apart for the time between them (more than 900 km/h) |

## Repo layout

```
playbooks/<scenario>/README.md      # step-by-step investigation guide
playbooks/<scenario>/queries/*.kql  # one query per step, numbered in order
detections/*.kql                    # proactive hunts / custom detection candidates
templates/playbook-template.md      # starting point for new playbooks
```

## How to use

1. Open the playbook for your alert type.
2. Fill in the `let` variables at the top of each query (user, alert time, IPs).
3. Run the queries in order and use the **Verdict** section to make a call.
4. If it's a true positive, follow the **Containment** checklist.

## Changelog

- **2026-11-09**: Initial release: impossible travel detection and account compromise playbook.
