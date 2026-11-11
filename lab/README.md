# Cloud Detection Engineering Lab

A hands-on project for practising **cloud security engineering**. It deploys a Microsoft Sentinel lab on Azure with **Terraform**, manages KQL detection rules **as code**, deploys them through **GitHub Actions**, and proves each rule works with recorded evidence.

Detection content comes from this repo's [detections](../detections/README.md) and [playbooks](../playbooks/). The Defender XDR rules (`detections/*.kql`) are converted into Sentinel analytics rules (`detections/sentinel/*.yaml`) and deployed by Terraform.

## Status

🚧 **In progress.** Follow the [learning guide](docs/learning-guide.md).

| Phase | Description | Status |
|---|---|---|
| 0 | Tooling and scaffold | ⬜ |
| 1 | Terraform fundamentals | ⬜ |
| 2 | Lab infrastructure (Log Analytics, Sentinel, VM, cost guardrails) | ⬜ |
| 3 | Detections as code (14 rules) | ⬜ |
| 4 | CI/CD with GitHub Actions (OIDC) | ⬜ |
| 5 | Detection testing and evidence | ⬜ |
| 6 | Hardening and posture (Conditional Access, Defender for Cloud, Azure Policy) | ⬜ |
| 7 | Portfolio wrap-up and teardown | ⬜ |

## Detection status

| Rule | MITRE | Deployed | Tested | Evidence |
|---|---|---|---|---|
| Impossible travel | T1078.004 | ⬜ | ⬜ | |
| AiTM: automation user agent sign-in | T1557, T1550.004 | ⬜ | ⬜ | |
| AiTM: click, then new-IP sign-in | T1566.002, T1539 | ⬜ | ⬜ | |
| AiTM: session replay with user agent change | T1539, T1550.004 | ⬜ | ⬜ | |
| Password spray: password correct or signed in | T1110.003 | ⬜ | ⬜ | |
| Legacy authentication success | T1078.004 | ⬜ | ⬜ | |
| BEC: high-risk inbox rule | T1564.008 | ⬜ | ⬜ | |
| BEC: external forwarding | T1114.003 | ⬜ | ⬜ | |
| BEC: VIP display name impersonation | T1656 | ⬜ | ⬜ | |
| Phishing: malicious URL click | T1204.001 | ⬜ | ⬜ | |
| PowerShell: Office spawning script engines | T1204.002, T1059.001 | ⬜ | ⬜ | |
| PowerShell: encoded download/execute | T1059.001, T1027.010 | ⬜ | ⬜ | |
| PowerShell: ClickFix (Run dialog) | T1204.004 | ⬜ | ⬜ | |
| PowerShell: Defender/AMSI tampering | T1562.001 | ⬜ | ⬜ | |

## Lab layout

```
lab/docs/               learning guide, build prompts, architecture, lab setup
lab/infra/terraform/    Terraform root + modules (log-analytics, sentinel, lab-vm, cost-guardrails)
lab/tests/simulations/  how to safely trigger each rule in the lab
lab/scripts/            validation and deployment helpers
lab/evidence/           screenshots and notes proving each rule fired
../detections/          Defender XDR rules (*.kql) + Sentinel versions (sentinel/*.yaml)
../.github/workflows/   lab-validate, lab-plan, lab-apply pipelines (GitHub requires the repo root)
```

## Getting started

1. Read the [learning guide](docs/learning-guide.md).
   - To deploy the workspace and Sentinel with Terraform, follow the [IaC walkthrough](docs/iac-walkthrough.md).
   - [Data connectors](docs/data-connectors.md) lists which connector and tables each rule needs.
   - [Troubleshooting log](docs/troubleshooting.md): real errors from building the lab and how they were fixed.
2. Use the [build prompts](docs/prompts.md) to scaffold the lab and convert the detections.
3. Work phase by phase, committing through pull requests.
