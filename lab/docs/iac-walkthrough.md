# IaC walkthrough: build the Sentinel lab with Terraform

Follow this top to bottom. By the end you will have deployed a Log Analytics workspace and Microsoft Sentinel from code, seen how the detection rules are gated, and collected the screenshots that prove it.

- 📸 marks a screenshot. Save them in `lab/evidence/lab-setup/` using the file name given.
- 🗣 marks how to explain the step to someone else.
- Commands are for PowerShell on Windows. On macOS/Linux, replace `$env:NAME = "value"` with `export NAME="value"`.

**Status of the code:** `terraform fmt` and `terraform validate` pass in the `lab-validate` GitHub Actions check. The KQL in the rules has not yet been run against a real workspace, so run each query in Sentinel Logs before enabling its rule.

**Cost:** the workspace has a 1 GB/day cap and no VM is created. With no data connected, tonight's resources cost close to nothing. Step 9 shows how to delete everything.

---

## 0. Prerequisites (10 min)

1. An Azure subscription where you are **Owner** (the free account works).
2. Install [Terraform](https://developer.hashicorp.com/terraform/install) 1.6 or newer, the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), Git and Python 3.
3. Check them:

```powershell
terraform version
az version
python --version
```

📸 `00-tool-versions.png`: the terminal showing all three versions.

## 1. Get the code (5 min)

```powershell
git clone https://github.com/kat0ps/defender-hunting-playbooks
cd defender-hunting-playbooks
git fetch origin
git checkout lab/sentinel-detections-as-code
pip install pyyaml
```

Open the folder in VS Code and look at these, in this order:

| Path | What it is |
|---|---|
| `detections/sentinel/legacy-auth-success.yaml` | One Sentinel rule as data. Compare it with `detections/legacy-auth-success.kql`. |
| `detections/sentinel/schema.md` | What every YAML field means. |
| `lab/infra/terraform/main.tf` | The root module: calls the two modules below. |
| `lab/infra/terraform/modules/log-analytics/main.tf` | Resource group + workspace with a daily cap. |
| `lab/infra/terraform/modules/sentinel/main.tf` | Sentinel onboarding + one rule per YAML file. |

🗣 "The detections are YAML files. Terraform reads the folder and creates one Sentinel analytics rule per file, so adding a detection is a pull request, not a portal click."

## 2. Validate the rule files (2 min)

```powershell
python lab/scripts/validate_detections.py
```

Expected: 14 lines starting with `ok` and `14 passed, 0 failed`.

📸 `01-validate-detections.png`: the full output.

Try breaking one: change `severity: Medium` to `severity: Critical` in `legacy-auth-success.yaml`, run it again, see it fail, then undo the change (`git checkout detections/sentinel/legacy-auth-success.yaml`).

🗣 "This script is a cheap first gate. It catches a bad GUID, a wrong severity or a missing table in a second, before Terraform ever talks to Azure."

## 3. Format and validate the Terraform offline (5 min)

```powershell
cd lab/infra/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

- `init -backend=false` downloads the `azurerm` and `azuread` providers but skips the state backend, so it needs no Azure login.
- `fmt -check` prints nothing when every file is correctly formatted.
- `validate` should print `Success! The configuration is valid.`

📸 `02-terraform-validate.png`: the `Success!` line.

`init` created `.terraform.lock.hcl`, which records the exact provider versions. Commit it later (step 8).

**If validate fails, stop and fix the error before going on.**

## 4. Sign in to Azure (5 min)

```powershell
az login
az account show --query "{name:name, id:id, tenant:tenantId}" -o table
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

The `azurerm` provider (version 4) refuses to run without a subscription ID. Setting it as an environment variable keeps it out of the repo.

Do **not** screenshot this output; it contains your subscription and tenant IDs.

## 5. Create the remote state storage (10 min, one time)

Terraform records what it built in a *state file*. This lab keeps it in an Azure Storage account so your laptop and GitHub Actions can share it later. This storage is created by hand, once, because Terraform can't store its state in something it hasn't created yet.

Pick a globally unique storage name (3-24 lowercase letters and digits).

```powershell
$STATE_RG = "rg-tfstate"
$STATE_SA = "sttfstate" + (Get-Random -Maximum 99999999)   # note this name down
az group create -n $STATE_RG -l southafricanorth
az storage account create -n $STATE_SA -g $STATE_RG -l southafricanorth --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false
az storage container create -n tfstate --account-name $STATE_SA --auth-mode login

# Let your own account read and write blobs (state is accessed with your Entra ID login, not a key).
$ME = az ad signed-in-user show --query id -o tsv
$SCOPE = az storage account show -n $STATE_SA -g $STATE_RG --query id -o tsv
az role assignment create --assignee $ME --role "Storage Blob Data Contributor" --scope $SCOPE
```

Wait about 2 minutes for the role to take effect, then:

```powershell
terraform init -reconfigure `
  -backend-config="resource_group_name=$STATE_RG" `
  -backend-config="storage_account_name=$STATE_SA" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=sentinel-lab.tfstate" `
  -backend-config="use_azuread_auth=true"
```

Expected: `Successfully configured the backend "azurerm"!` A 403 error means the role hasn't propagated yet; wait and rerun.

📸 `03-terraform-init-backend.png`: the "Successfully configured the backend" message.

🗣 "State is remote and accessed with my identity, not a storage key, so there is no secret to leak."

## 6. Plan and apply: workspace and Sentinel, no rules (15 min)

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars`. Leave `available_tables = []` and `enabled_rules = ["legacy-auth-success"]` as they are. The file is git-ignored.

```powershell
terraform plan -out tfplan
```

Read the plan before doing anything else. You should see:

- `Plan: 3 to add, 0 to change, 0 to destroy.` The three are the resource group, the workspace and the Sentinel onboarding.
- **No** `azurerm_sentinel_alert_rule_scheduled`. The rule is held back.
- Under "Changes to Outputs": `skipped_rules` shows `legacy-auth-success` with `AADNonInteractiveUserSignInLogs` and `SigninLogs`, and `missing_tables` lists the same two tables.

📸 `04-plan-summary.png`: the `Plan: 3 to add` line and the outputs showing the skipped rule.

🗣 "Sentinel rejects a rule if its table doesn't exist yet. Instead of a failed deployment, the module holds the rule back and tells me which tables are missing, so I know which connector to enable next."

Now apply. This is the step that creates real resources:

```powershell
terraform apply tfplan
```

📸 `05-apply-complete.png`: `Apply complete! Resources: 3 added` plus the outputs.

If apply fails with a message about a resource provider not being registered, run `az provider register --namespace Microsoft.SecurityInsights` and `az provider register --namespace Microsoft.OperationalInsights`, wait a few minutes and apply again.

## 7. Check it in the portal (10 min)

1. Azure portal → Resource groups → `rg-sentinel-lab`.
   📸 `06-resource-group.png`: the resource list showing `law-sentinel-lab`.
2. Open `law-sentinel-lab` → Usage and estimated costs → Daily cap.
   📸 `07-daily-cap.png`: the cap set to 1 GB/day.
3. Search for **Microsoft Sentinel** → select `law-sentinel-lab`. (New workspaces may open in the Defender portal at security.microsoft.com; that is fine.)
   📸 `08-sentinel-overview.png`: the Sentinel overview for the workspace.
4. Sentinel → Configuration → Analytics.
   📸 `09-analytics-empty.png`: no active rules yet, matching the plan.
5. Back in the terminal:

```powershell
terraform state list
terraform output
```

📸 `10-state-and-outputs.png`: three resources in state, and `skipped_rules` populated.

🗣 "Everything in that resource group came from code. Nothing was clicked."

## 8. Commit your evidence (5 min)

```powershell
cd ../../..
git add lab/infra/terraform/.terraform.lock.hcl lab/evidence/lab-setup
git commit -m "Lab: add provider lock file and IaC deployment evidence"
git push
```

Then open the pull request on GitHub and check that the `lab-validate` workflow is green.

📸 `11-pr-checks-green.png`: the pull request's Checks section.

Before committing, look at each screenshot and crop out any subscription ID, tenant ID or email address.

## 9. Stretch: deploy your first rule (needs data, so probably tomorrow)

1. Sentinel → Content hub → install **Microsoft Entra ID** → open the connector → tick **Sign-in logs** and **Non-interactive user sign-in logs** → Apply. This needs an Entra ID P1/P2 licence in the same tenant as the subscription (the M365 E5 trial includes it) and the Security Administrator role. See [data-connectors.md](data-connectors.md).
   📸 `12-entra-connector.png`: the connector showing as connected.
2. Sign out and in a few times, then wait. First data can take from 15 minutes up to a few hours.
3. Sentinel → Logs: run `SigninLogs | take 5` and `AADNonInteractiveUserSignInLogs | take 5`. Both must return rows without a "could not resolve table" error.
   📸 `13-signinlogs-data.png`: rows returned.
4. In `terraform.tfvars` set:

```hcl
available_tables = ["SigninLogs", "AADNonInteractiveUserSignInLogs"]
enabled_rules    = ["legacy-auth-success"]
```

5. `terraform plan -out tfplan` should now show `1 to add`: the analytics rule. Then `terraform apply tfplan`.
   📸 `14-plan-one-rule.png` and `15-rule-in-analytics.png` (the rule listed under Analytics).
6. Remove the `enabled_rules` line to deploy the other four sign-in rules.

## 10. Clean up when you're done practising

To stop all cost and practise the full lifecycle:

```powershell
cd lab/infra/terraform
terraform destroy
```

Read the list, then type `yes`. This deletes the resource group, the workspace and its data. You can rebuild it with `terraform apply` in a few minutes, which is the point of infrastructure as code. Leave `rg-tfstate` in place; it costs almost nothing and holds your state.

---

## What you can now explain

| Question | Answer |
|---|---|
| What is IaC? | The lab is described in files. `plan` shows the difference between the files and Azure; `apply` makes Azure match. |
| What is a module? | A reusable folder of resources with inputs and outputs. `log-analytics` outputs the workspace ID; `sentinel` takes it as an input. |
| What is state? | Terraform's record of what it created, kept in Azure Storage and locked while a run is in progress. |
| Why `for_each`? | One resource block creates one rule per YAML file. The file name is the key, so each rule can be added or removed on its own. |
| Why `available_tables`? | Sentinel refuses a rule whose tables don't exist. The gate deploys a rule only when its data is flowing. |
| Why `enabled_rules`? | To roll rules out one at a time and check each in the portal. |
| Why the daily cap? | Ingestion is billed per GB. The cap is a hard stop on cost. |
| Why no secrets in the repo? | Subscription ID comes from an environment variable, state access uses your login, and `*.tfvars` is git-ignored. |
