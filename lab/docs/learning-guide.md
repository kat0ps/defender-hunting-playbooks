# Learning Guide: Cloud Detection Engineering Lab

A step-by-step path from "I write KQL" to "I deploy and manage security detections as code on Azure". Each phase ends with something you commit to GitHub, so the repo history shows your progress.

**Time:** about 4–6 weeks at a few hours a week
**Tools:** Azure free account, Microsoft 365 E5 trial, GitHub, VS Code, Terraform, Azure CLI

> ⚠️ **The Azure credit (30 days) and the M365 E5 trial (30 days) expire.** Do phases 0–1 first, which cost nothing. Only start the trials when you begin phase 2, so you get the most out of them.

---

## Phase 0: Set up your tools (free, about 2 hours)

**Learn:** Git branching and pull requests, VS Code extensions (HashiCorp Terraform, YAML, Kusto).

1. Install VS Code, Git, the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and [Terraform](https://developer.hashicorp.com/terraform/install).
2. Clone this repo and run **Prompt 1** from [prompts.md](prompts.md) to scaffold the `lab/` folders.
3. Work on branches: `git checkout -b phase-0-scaffold`, then open a pull request into `main`, even though you're working alone. PRs are part of the evidence.

**Commit:** the folder scaffold, via your first pull request.

---

## Phase 1: Terraform fundamentals (free, about 1 week)

**Learn:** providers, resources, variables, outputs, state, modules, `for_each`, `fileset()`, `yamldecode()`.

1. Work through HashiCorp's **Get Started – Azure** tutorials (developer.hashicorp.com/terraform/tutorials/azure-get-started).
2. Read about remote state in Azure Storage, and why state must never be committed.
3. Practise locally with `terraform fmt`, `terraform validate` and `terraform plan` on the scaffold. You don't need an Azure subscription to validate.

**Check you understand it:** can you explain what `terraform plan` shows, and why state files are sensitive?

**Commit:** a filled-in `variables.tf`, `providers.tf` and `terraform.tfvars.example`, plus notes in `lab/docs/` on what you learned.

---

## Phase 2: Build the lab with infrastructure as code (start the trials, about 1 week)

**Learn:** Log Analytics, Sentinel onboarding, data connectors, cost controls.

1. **Start the trials** (follow [lab-setup.md](lab-setup.md)):
   - The Azure free account
   - The Microsoft 365 E5 trial, which includes Entra ID P2, Defender for Endpoint P2 and Defender for Office 365 P2
2. **Cost guardrails first.** Deploy the `cost-guardrails` module (budget alerts) before anything else.
3. Deploy the `log-analytics` module (workspace with a daily cap), then the `sentinel` module with **no rules yet**.
4. **Connect data** (some connectors are easiest done in the portal at first; note which ones):
   - Entra ID sign-in and audit logs → workspace
   - Microsoft 365 (OfficeActivity)
   - Microsoft Defender XDR connector
5. Deploy the `lab-vm` module, onboard the VM to Defender for Endpoint, and confirm `DeviceProcessEvents` data arrives.

**Check you understand it:** can you draw the data flow from VM, Entra ID and Exchange into Sentinel?

**Commit:** working modules, `lab/docs/architecture.md` with a diagram, and screenshots of data arriving, in `lab/evidence/lab-setup/`.

---

## Phase 3: Detections as code (about 1 week)

**Learn:** the Sentinel analytics rule schema, entity mapping, Defender-to-Sentinel KQL conversion.

1. Run **Prompt 2** from [prompts.md](prompts.md).
2. **Review every converted query yourself.** Run each one in the Sentinel Logs blade before deploying it. The conversion is where the learning happens: why `ResultType` is a string, why `SigninLogs` and `AADNonInteractiveUserSignInLogs` are separate tables, how entity mapping works.
3. Deploy **one rule** (`enabled_rules = ["legacy-auth-success"]`), check it appears under Sentinel → Analytics, then add the rest.

**Check you understand it:** can you explain queryFrequency vs queryPeriod, and why entity mapping matters for incidents?

**Commit:** 14 YAML rules in `detections/sentinel/`, the Sentinel module with `for_each`, and the validation script.

---

## Phase 4: CI/CD with GitHub Actions (about 1 week)

**Learn:** OIDC federated credentials, GitHub environments, plan-on-PR / apply-on-merge.

1. Create an Entra app registration with a **federated credential** for your repo (no secrets) and give it a least-privilege role on the lab resource group: **Microsoft Sentinel Contributor** plus what Terraform needs.
2. Store the Terraform state in an Azure Storage account.
3. Build the three workflows:
   - **validate.yml:** fmt, validate, YAML schema check
   - **plan.yml:** `terraform plan` posted as a PR comment
   - **apply.yml:** `terraform apply` on merge, behind a GitHub environment with required approval
4. Test the full loop: change a rule's severity on a branch, open a PR, review the plan, merge, and confirm the change in Sentinel.

**Check you understand it:** why is OIDC safer than storing a client secret in GitHub?

**Commit:** the workflows, plus screenshots of a green pipeline and a plan comment on a PR.

---

## Phase 5: Test every detection and collect evidence (about 1 week)

**Learn:** attack simulation, alert tuning, writing evidence.

For each rule, follow its `lab/tests/simulations/<rule>.md`:
1. Trigger it safely in **your own lab tenant only** (test users, benign commands, test mailboxes).
2. Confirm the alert or incident in Sentinel or Defender.
3. Save a screenshot to `lab/evidence/<rule>/` with a short `notes.md` covering what you did, when it fired, and any tuning you made.
4. Update the status table in `lab/README.md`: Deployed ✅, Tested ✅, Evidence link.

Useful sources of safe tests: Atomic Red Team (MITRE-mapped tests), Defender's built-in attack simulation training, and the EICAR test file.

**Commit:** one PR per rule, or batch them. A full status table is your strongest portfolio piece.

---

## Phase 6: Hardening and posture, the cloud security engineering layer (about 1 week)

**Learn:** Conditional Access, Defender for Cloud, Azure Policy, identity security.

1. **Conditional Access as code** (azuread provider or Graph): block legacy auth, require MFA, require compliant devices for admins. Show the matching detection going quiet after the policy is in place, for example `legacy-auth-success`.
2. **Defender for Cloud:** record your secure score, fix the top recommendations with Terraform, then record it again.
3. **Azure Policy:** assign policies (e.g. require diagnostic settings, deny public IPs on VMs) with Terraform.

**Commit:** policy code plus before/after evidence. A detection that stops firing because you fixed the root cause makes a great story for interviews.

---

## Phase 7: Wrap up the portfolio

1. Finish `lab/README.md`: architecture diagram, what you built, a skills list, the status table, and links to the evidence.
2. Write a short case study: "Detections as code on Azure: what I built and learned".
3. **Tear down:** run `terraform destroy` before the trials end, and screenshot the empty resource group. Clean teardown is an engineering skill too.
4. Optional next steps: SC-200 (Security Operations Analyst), AZ-500 (Azure Security Engineer), HashiCorp Terraform Associate.

---

## Skills this project demonstrates

| Skill | Where it shows |
|---|---|
| Infrastructure as code (Terraform) | `lab/infra/terraform/` |
| Detection engineering (KQL, MITRE) | `detections/` (Defender) and `detections/sentinel/` (Sentinel) |
| Detection as code / CI/CD | `.github/workflows/` |
| Secure pipelines (OIDC, least privilege, approvals) | Phase 4 setup |
| Cloud cost governance | `cost-guardrails` module |
| Identity and posture hardening | Phase 6 |
| Validation and evidence | `lab/tests/`, `lab/evidence/` |

## Safety rules

- Only run simulations in **your own** lab tenant, never at work or against anyone else.
- No real malware: use benign commands, test strings and Microsoft's simulation tools.
- Never commit secrets, IDs, state files or screenshots that show real people's data.
