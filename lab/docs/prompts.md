# Build Prompts

Paste these into Claude Code (or Claude with this repo connected), one at a time, in order. Each prompt is self-contained.

The lab lives **inside this repo**:
- Defender XDR rules stay in `detections/*.kql` (the source of truth, linked from the playbooks).
- Sentinel versions go in `detections/sentinel/*.yaml`.
- Infrastructure, tests and evidence go in `lab/`.
- GitHub Actions workflows must sit at the repo root in `.github/workflows/`, because GitHub only reads them there.

---

## Prompt 1: Scaffold the lab folders

```
In my repo "defender-hunting-playbooks" (github.com/kat0ps/defender-hunting-playbooks),
add a cloud security engineering lab that deploys Microsoft Sentinel on Azure with
Terraform and manages my KQL detection rules as code with GitHub Actions.

Don't touch the existing playbooks/, templates/ or detections/*.kql files.

Create this structure (some folders already exist with .gitkeep files):

├── detections/
│   ├── *.kql                     # EXISTING Defender XDR rules (don't modify)
│   ├── README.md                 # EXISTING index (add a short "Sentinel versions" section)
│   └── sentinel/                 # one YAML file per Sentinel analytics rule
│       └── schema.md             # documents the YAML fields
├── lab/
│   ├── README.md                 # lab overview, architecture, how to deploy, phase + detection status tables
│   ├── docs/
│   │   ├── learning-guide.md     # (already exists; don't overwrite)
│   │   ├── prompts.md            # (already exists; don't overwrite)
│   │   ├── architecture.md       # components and data flow (include a Mermaid diagram)
│   │   └── lab-setup.md          # one-time manual steps: Azure free account, M365 E5 trial, budget alert
│   ├── infra/
│   │   └── terraform/
│   │       ├── providers.tf      # azurerm (pinned ~> 4.x), azuread
│   │       ├── backend.tf        # azurerm remote state (values supplied at init time)
│   │       ├── variables.tf
│   │       ├── terraform.tfvars.example
│   │       ├── main.tf           # calls the modules below
│   │       ├── outputs.tf
│   │       └── modules/
│   │           ├── log-analytics/   # resource group + Log Analytics workspace (daily_quota_gb variable, default 1)
│   │           ├── sentinel/        # Sentinel onboarding + analytics rules loaded from detections/sentinel/*.yaml
│   │           ├── lab-vm/          # Windows test VM (see VM rules below)
│   │           └── cost-guardrails/ # subscription budget (default USD 150) with email alerts at 50/80/100%
│   ├── tests/
│   │   └── simulations/          # one markdown file per rule: how to safely trigger it in my own lab tenant
│   ├── scripts/                  # helper scripts (e.g. validate_detections.py)
│   └── evidence/                 # screenshots and notes proving each rule fired, one folder per rule
└── .github/
    └── workflows/
        ├── lab-validate.yml      # on PR touching lab/** or detections/sentinel/**: terraform fmt/validate, YAML schema check
        ├── lab-plan.yml          # on PR: terraform plan (working-directory lab/infra/terraform), posted as a PR comment
        └── lab-apply.yml         # on push to main: terraform apply (manual approval via GitHub environment)

VM rules (lab-vm module):
- Image: Windows 11 Enterprise (licensed by my Microsoft 365 E5 trial) as the default, with a
  variable to switch to Windows Server 2022 Datacenter.
- Size: Standard_B2s by default (variable). B1s is too small for Windows.
- No public IP and no open RDP. Default to Just-in-Time VM access restricted to an
  "allowed_admin_ip" variable. Only use Azure Bastion Developer if it's available in the chosen
  region; check the docs and add a comment.
- Auto-shutdown at 19:00 "South Africa Standard Time" (azurerm_dev_test_global_vm_shutdown_schedule).
- Variable "deploy_vm" (default false) so I can deploy the workspace and Sentinel without paying for a VM.

Rules:
- The repo root already has a .gitignore. Append Terraform entries if any are missing
  (.terraform/, *.tfstate*, *.tfvars except *.tfvars.example), but DO commit .terraform.lock.hcl.
- Use path filters so the workflows only run when lab/** or detections/sentinel/** change.
- Use OIDC (federated credentials) for GitHub Actions to Azure, never client secrets.
- Never commit secrets, tenant IDs or subscription IDs; use GitHub secrets and tfvars.example placeholders.
- Every Terraform module needs a short README.md with inputs and outputs.
- Region default: southafricanorth (variable).
- Add a link to lab/README.md from the root README.md.
- Keep code commented for a learner: explain WHY each resource exists.
When you're done, run terraform fmt and terraform validate (with -backend=false) and fix any errors.
Don't deploy anything; just create the files.
```

---

## Prompt 2: Detections as code (IaC for all 14 detections)

```
In my repo "defender-hunting-playbooks", convert all 14 Defender XDR detection rules in
detections/*.kql into Microsoft Sentinel scheduled analytics rules managed by Terraform
in lab/infra/terraform. Don't modify the original .kql files.

The 14 rules are:
impossible-travel, aitm-automation-useragent-signin, aitm-click-then-new-ip-signin,
aitm-session-replay-useragent-change, password-spray-compromise, legacy-auth-success,
bec-suspicious-inbox-rule, bec-external-forwarding, bec-vip-impersonation,
phishing-malicious-url-click, powershell-office-child-process, powershell-encoded-download,
powershell-clickfix-runmru, powershell-defender-tampering

STEP 1: For each rule, create detections/sentinel/<rule-name>.yaml with this schema:
  id: <stable GUID>
  name: <display name>
  description: <what it detects + link to the playbook in playbooks/>
  severity: Low|Medium|High
  enabled: true
  queryFrequency: PT1H | PT3H | PT24H     (ISO 8601, from the .kql header)
  queryPeriod: <lookback, ISO 8601>
  triggerOperator: GreaterThan
  triggerThreshold: 0
  tactics: [ ... ]                        (MITRE tactic names Sentinel accepts, e.g. InitialAccess)
  techniques: [ T1078, ... ]              (parent technique IDs only; list sub-techniques in the description)
  entityMappings: [ {entityType, fieldMappings: [{identifier, columnName}]} ]
  requiredDataConnectors: [ ... ]
  requiredTables: [ SigninLogs, ... ]     (every table the query reads)
  sourceRule: ../<rule-name>.kql          (link back to the Defender version)
  query: |
    <KQL converted for a Sentinel Log Analytics workspace>

Conversion rules for the KQL (Defender XDR -> Sentinel workspace):
- Timestamp -> TimeGenerated; remove ReportId (not needed in Sentinel).
- EntraIdSignInEvents -> union of SigninLogs and AADNonInteractiveUserSignInLogs
  (AccountUpn -> UserPrincipalName, AccountObjectId -> UserId, ErrorCode -> ResultType (string),
   Country/City/Latitude/Longitude -> LocationDetails.*, Application -> AppDisplayName,
   AadDeviceId/IsManaged/IsCompliant -> DeviceDetail.*). Parse LocationDetails/DeviceDetail
   with parse_json where the column is a string (non-interactive table).
- CloudAppEvents mailbox/inbox-rule actions -> OfficeActivity (Operation, UserId, ClientIP, Parameters).
- EmailEvents, UrlClickEvents, EmailPostDeliveryEvents and Device* tables: keep the same table
  names (they exist in Sentinel when the Microsoft Defender XDR connector streams raw events),
  switch Timestamp -> TimeGenerated, and list "MicrosoftThreatProtection" in requiredDataConnectors.
- Remove ago() windows that conflict with queryPeriod (Sentinel applies queryPeriod itself),
  except baselines that need a longer history (keep those explicit).
- Verify every column against the official Sentinel/Log Analytics table schemas. If a column
  doesn't exist, find the equivalent and add a comment explaining the change. Never invent a
  column name; if you can't confirm one, leave a "# TODO: verify column" comment.

Entity mapping identifiers to use:
  Account: AadUserId (UserId) or FullName (UserPrincipalName)
  IP: Address
  Host: HostName
  Mailbox: MailboxPrimaryAddress
  URL: Url

STEP 2: In lab/infra/terraform/modules/sentinel/:
- Onboard Sentinel with azurerm_sentinel_log_analytics_workspace_onboarding.
- Take a variable "rules_path" (set from the root module to "${path.root}/../../../detections/sentinel").
- Load every YAML file with fileset() + yamldecode() and create one
  azurerm_sentinel_alert_rule_scheduled per file with for_each (key = file name),
  including dynamic entity_mapping blocks.
- IMPORTANT: Sentinel rejects an analytics rule if any table in its query doesn't exist in the
  workspace yet. Add a variable "available_tables" (list of tables that currently have data) and only
  create rules whose requiredTables are all in that list. Output the names of skipped rules and the
  missing tables, so I can see which connector to enable next.
- Also add a variable "enabled_rules" (list, default = all) so I can deploy rules one at a time while learning.
  A rule is deployed only if it's in enabled_rules AND all its tables are available.

STEP 2b: Add lab/docs/data-connectors.md listing, for each rule, which connector and tables it needs.
Include a cost warning: streaming Defender XDR raw tables into Sentinel is billed as ingestion, so only
stream the tables these rules need (DeviceProcessEvents, DeviceRegistryEvents, EmailEvents,
EmailPostDeliveryEvents, UrlClickEvents), and keep the workspace daily cap on.

STEP 3: Add lab/scripts/validate_detections.py (Python 3, standard library + PyYAML only) that checks
every YAML file has the required fields, a valid GUID, valid severity, ISO 8601 durations, a non-empty
requiredTables list, an existing sourceRule file, and no duplicate ids. It must exit non-zero on failure.
Call it from .github/workflows/lab-validate.yml.

STEP 4: For each rule, create lab/tests/simulations/<rule-name>.md with: prerequisites, safe steps
to trigger it in my own lab tenant only (benign commands, test users, test mailboxes; no real
malware), expected alert, and an evidence checklist (screenshots to capture into lab/evidence/<rule-name>/).

STEP 5: Update the detection status table in lab/README.md with all 14 rules (Deployed/Tested = No),
and add a "Sentinel version" column to detections/README.md linking each rule to its YAML.

Explain each file you create in a short comment so I can learn from it.
Run terraform fmt and terraform validate, and the validation script, and fix any errors.
Don't run terraform apply.
```

---

## Prompt 3 (optional, advanced): Defender XDR custom detections as code

```
In my repo "defender-hunting-playbooks", add a way to deploy detections/*.kql as Microsoft
Defender XDR custom detection rules using the Microsoft Graph security detectionRules API
(check the current API version and required permissions in the docs first; it may be beta).

- Add detections/defender-metadata/<rule>.yaml next to each .kql (name, severity, frequency,
  MITRE, impacted entity column mapping) based on the header comments in each .kql file.
- Write lab/scripts/deploy-defender-rules.ps1 that creates or updates rules idempotently
  (match on display name).
- Add a manual-trigger workflow .github/workflows/lab-defender-deploy.yml using OIDC to an app
  registration with the minimum Graph permission needed.
- Document the setup and limitations in lab/docs/defender-detections-as-code.md.
```
