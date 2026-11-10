# IaC walkthrough: build the Sentinel lab with Terraform

Follow this top to bottom. By the end you will have deployed a Log Analytics workspace and Microsoft Sentinel from code, seen how the detection rules are gated, and collected the screenshots that prove it.

- 📍 says **where** you do the step: which app, and for terminal steps, which folder.
- 📸 marks a screenshot, with the window to capture and the file name to use.
- 💡 explains the step in plain words, with an everyday comparison. Read it before you run anything.
- 🗣 marks how to explain the step to someone else.

**Status of the code:** `terraform fmt` and `terraform validate` pass in the `lab-validate` GitHub Actions check. The KQL in the rules has not yet been run against a real workspace, so run each query in Sentinel Logs before enabling its rule.

**Cost:** the workspace has a 1 GB/day cap and no VM is created. With no data connected, tonight's resources cost close to nothing. Step 10 shows how to delete everything.

## The places you will work

| Name used in this guide | What it is | How to open it |
|---|---|---|
| **Terminal** | PowerShell on your own computer | In VS Code: menu **Terminal → New Terminal**. Keep the same terminal open for steps 1 to 8; the variables you set are lost if you close it. |
| **VS Code** | The editor, for reading and editing files | Open VS Code → **File → Open Folder** → the `defender-hunting-playbooks` folder |
| **Azure portal** | Your browser at <https://portal.azure.com> | Sign in with the account that owns the subscription |
| **GitHub** | Your browser at <https://github.com/kat0ps/defender-hunting-playbooks> | Sign in as `kat0ps` |
| **Evidence folder** | `lab/evidence/lab-setup/` inside the repo | Create it in step 1; save every screenshot there |

## Plain-English dictionary

You don't need to memorise this. Come back to it whenever a word is unclear.

**The big picture:** think of a shopping centre's security office. Cameras all over the building send footage to a recording room. A guard watches the recordings and follows written instructions such as "if someone opens the back door after midnight, raise the alarm". This lab builds that security office in Azure, for computer logs instead of camera footage. And instead of building it by clicking, you hand a builder a written plan.

| Word | In plain words | Everyday comparison |
|---|---|---|
| **Azure** | Microsoft's cloud: computers and services you rent over the internet | A building where you rent rooms instead of buying your own |
| **Subscription** | The account that everything you create is billed to | Your electricity account |
| **Resource** | Any single thing you create in Azure | One appliance plugged in at home |
| **Resource group** | A container that holds related resources | A box you pack things into; throw away the box and everything in it goes |
| **Log** | A record that something happened: "Kat signed in at 20:15 from this address" | One line in a visitors' book |
| **Log Analytics workspace** | The place in Azure where logs are stored and searched | The recording room and its filing cabinet |
| **Table** | One kind of log inside the workspace, for example `SigninLogs` | One drawer in the filing cabinet |
| **Data connector** | The link that sends logs from a source (such as Entra ID sign-ins) into the workspace | The cable from a camera to the recording room |
| **Microsoft Sentinel** | The security tool that sits on the workspace, watches the logs and raises alerts. This kind of tool is called a SIEM | The guard watching the recordings |
| **Analytics rule** | A saved search that runs on a timer and creates an alert when it finds something | One written instruction for the guard |
| **KQL** | The language used to search the logs | The way you phrase a question to the filing clerk |
| **Incident** | The case Sentinel opens when a rule finds something | The guard's incident report |
| **IaC (infrastructure as code)** | Describing what you want built in text files, instead of clicking in the portal | A written building plan instead of telling the builder as you go |
| **Terraform** | The tool that reads those files and builds what they describe | The builder |
| **Provider** | A plugin that teaches Terraform how to talk to one platform, here Azure | The builder's set of tools for one type of job |
| **`terraform init`** | Gets Terraform ready: downloads the providers and connects to the state | The builder unpacking tools on site |
| **`terraform plan`** | Shows what would be created, changed or deleted. Changes nothing | A quote: "here is what I will do" |
| **`terraform apply`** | Actually makes the changes in Azure | The builder doing the work |
| **`terraform destroy`** | Deletes everything Terraform built | Demolition |
| **State** | Terraform's own record of what it has built | The builder's notebook, so they know what already exists |
| **Module** | A reusable bundle of Terraform files with settings going in and results coming out | A flat-pack kit with its own instruction sheet |
| **Variable** | A setting you can change without editing the code | A blank on a form |
| **Output** | A value Terraform prints when it finishes | The receipt |
| **YAML** | A simple text format of `name: value` lines. Each detection rule is one YAML file | A filled-in form |
| **Git** | Keeps a history of every change to your files | "Track changes" for a whole folder |
| **Branch** | A separate copy of the project where changes are made safely | A draft |
| **Pull request** | A request to merge a branch into the main copy, with review and checks | Handing in the draft for marking |
| **GitHub Actions** | Robots on GitHub that run checks automatically on every pull request | An automatic spell-check before anything is accepted |

Two folders matter in the Terminal. The prompt shows which one you are in:

- **Repo root:** `...\defender-hunting-playbooks`
- **Terraform folder:** `...\defender-hunting-playbooks\lab\infra\terraform`

To take a screenshot on Windows, press **Win + Shift + S**, drag over the area, click the notification, and **Save as** into the Evidence folder with the file name given.

Commands are for PowerShell on Windows. On macOS/Linux, replace `$env:NAME = "value"` with `export NAME="value"` and the backtick line endings with `\`.

---

## 0. Prerequisites (10 min)

💡 **In plain words:** before building anything you need the tools. Terraform is the builder, the Azure CLI lets you talk to Azure by typing instead of clicking, Git fetches and saves the project, Python runs the checking script, and VS Code is where you read and edit files.

📍 **Browser**, then **Terminal** (any folder).

1. In the **browser**: confirm you have an Azure subscription where you are **Owner** (the free account works). Azure portal → search **Subscriptions** → open yours → **Access control (IAM)** → **View my access**.
2. In the **browser**: download and install [Terraform](https://developer.hashicorp.com/terraform/install) 1.6 or newer, the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), [Git](https://git-scm.com/downloads), [Python 3](https://www.python.org/downloads/) and [VS Code](https://code.visualstudio.com/).
3. Open a **new Terminal** (so it picks up the installs) and run:

```powershell
terraform version
az version
python --version
git --version
```

📸 `00-tool-versions.png`: the **Terminal** showing the versions.

## 1. Get the code (5 min)

💡 **In plain words:** the project lives on GitHub. `git clone` downloads your own copy. `git checkout` switches to the branch (the draft) that contains the new lab files. Then you read a few files so the later steps make sense. Reading costs nothing and changes nothing.

📍 **Terminal**, in the folder where you keep your projects (for example `C:\Users\<you>\source`).

```powershell
git clone https://github.com/kat0ps/defender-hunting-playbooks
cd defender-hunting-playbooks
git fetch origin
git checkout lab/sentinel-detections-as-code
pip install pyyaml
mkdir -Force lab/evidence/lab-setup
```

You are now in the **repo root**. If you already have the repo cloned, `cd` into it and run only the last four lines.

📍 **VS Code**: **File → Open Folder** → select `defender-hunting-playbooks`. From now on use the terminal inside VS Code (**Terminal → New Terminal**); it opens in the repo root.

In the VS Code file explorer (left side), open and read these, in this order:

| Path | What it is |
|---|---|
| `detections/sentinel/legacy-auth-success.yaml` | One Sentinel rule as data. Compare it with `detections/legacy-auth-success.kql`. |
| `detections/sentinel/schema.md` | What every YAML field means. |
| `lab/infra/terraform/main.tf` | The root module: calls the two modules below. |
| `lab/infra/terraform/modules/log-analytics/main.tf` | Resource group + workspace with a daily cap. |
| `lab/infra/terraform/modules/sentinel/main.tf` | Sentinel onboarding + one rule per YAML file. |

🗣 "The detections are YAML files. Terraform reads the folder and creates one Sentinel analytics rule per file, so adding a detection is a pull request, not a portal click."

## 2. Validate the rule files (2 min)

💡 **In plain words:** each detection rule is a form with fields like name, severity and how often to run. This script is a spell-checker for those forms. It only reads files on your computer; it doesn't touch Azure.

📍 **Terminal**, in the **repo root**.

```powershell
python lab/scripts/validate_detections.py
```

Expected: 14 lines starting with `ok` and `14 passed, 0 failed`.

📸 `01-validate-detections.png`: the **Terminal** with the full output.

Try breaking one:

1. 📍 **VS Code**: open `detections/sentinel/legacy-auth-success.yaml`, change `severity: Medium` to `severity: Critical`, and save.
2. 📍 **Terminal** (repo root): run the script again and see it fail.
3. 📍 **Terminal** (repo root): undo the change with `git checkout detections/sentinel/legacy-auth-success.yaml`.

🗣 "This script is a cheap first gate. It catches a bad GUID, a wrong severity or a missing table in a second, before Terraform ever talks to Azure."

## 3. Format and validate the Terraform offline (5 min)

💡 **In plain words:** now you check the building plan itself. `init` unpacks the builder's tools. `fmt` checks the plan is neatly laid out. `validate` checks the plan makes sense, for example that no setting is misspelled. Still nothing is built and you aren't even signed in to Azure yet.

📍 **Terminal**. Start in the repo root; the first command moves you to the **Terraform folder**, where you stay until step 8.

```powershell
cd lab/infra/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

- `init -backend=false` downloads the `azurerm` and `azuread` providers (the Azure toolsets) but skips connecting to the state notebook, so it needs no Azure login.
- `fmt -check` prints nothing when every file is correctly formatted.
- `validate` should print `Success! The configuration is valid.`

📸 `02-terraform-validate.png`: the **Terminal** showing the `Success!` line.

`init` created `.terraform.lock.hcl` in the Terraform folder. It records the exact provider versions. You commit it in step 8.

**If validate fails, stop and fix the error before going on.**

## 4. Sign in to Azure (5 min)

💡 **In plain words:** the builder needs to know who you are and which account pays. `az login` proves who you are. The last line tells Terraform which subscription to build in, a bit like giving the builder the site address.

📍 **Terminal**, in the **Terraform folder**. `az login` opens a **browser** window: sign in there, then return to the Terminal.

```powershell
az login
az account show --query "{name:name, id:id, tenant:tenantId}" -o table
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

If you have more than one subscription, pick the lab one first with `az account set --subscription "<name>"`.

The `azurerm` provider (version 4) refuses to run without a subscription ID. Setting it as an environment variable keeps it out of the repo. It only lasts for this Terminal window; if you open a new one, run the last line again.

Do **not** screenshot this output; it contains your subscription and tenant IDs.

## 5. Create the remote state storage (10 min, one time)

💡 **In plain words:** the builder keeps a notebook of everything already built (the state). If the notebook were only on your laptop and the laptop died, the builder would forget what exists. So you keep the notebook in a safe place in Azure. You create that safe place by hand, once, because the builder can't keep a notebook inside something that hasn't been built yet. The role assignment gives you, personally, permission to open it.

📍 **Terminal**, in the **Terraform folder**. The commands create resources in **Azure** (a resource group named `rg-tfstate`); nothing changes on your computer.

Terraform records what it built in a *state file*. This lab keeps it in an Azure Storage account so your laptop and GitHub Actions can share it later. This storage is created by hand, once, because Terraform can't store its state in something it hasn't created yet.

```powershell
$STATE_RG = "rg-tfstate"
$STATE_SA = "sttfstate" + (Get-Random -Maximum 99999999)
echo $STATE_SA      # write this name down; you need it every time you run terraform init
az group create -n $STATE_RG -l southafricanorth
az storage account create -n $STATE_SA -g $STATE_RG -l southafricanorth --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false
az storage container create -n tfstate --account-name $STATE_SA --auth-mode login

# Let your own account read and write blobs (state is accessed with your Entra ID login, not a key).
$ME = az ad signed-in-user show --query id -o tsv
$SCOPE = az storage account show -n $STATE_SA -g $STATE_RG --query id -o tsv
az role assignment create --assignee $ME --role "Storage Blob Data Contributor" --scope $SCOPE
```

📍 **Azure portal** (optional check): search **Resource groups** → `rg-tfstate` → you should see the storage account.

Wait about 2 minutes for the role to take effect.

📍 **Terminal**, in the **Terraform folder**:

```powershell
terraform init -reconfigure `
  -backend-config="resource_group_name=$STATE_RG" `
  -backend-config="storage_account_name=$STATE_SA" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=sentinel-lab.tfstate" `
  -backend-config="use_azuread_auth=true"
```

Expected: `Successfully configured the backend "azurerm"!` A 403 error means the role hasn't taken effect yet; wait and run it again.

📸 `03-terraform-init-backend.png`: the **Terminal** showing "Successfully configured the backend". Crop out the storage account name if you prefer not to publish it.

🗣 "State is remote and accessed with my identity, not a storage key, so there is no secret to leak."

## 6. Plan and apply: workspace and Sentinel, no rules (15 min)

💡 **In plain words:** this is the main event, in three parts. First you fill in your settings (the `terraform.tfvars` file). Then `plan` gives you a quote: it lists what it would build, and builds nothing. Only `apply` does the work. Tonight it builds three things: the box (resource group), the recording room (workspace) and the guard (Sentinel). It gives the guard no instructions yet, because the cameras aren't connected, and Sentinel won't accept an instruction about footage that doesn't exist.

📍 **Terminal**, in the **Terraform folder**:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

📍 **VS Code**: open `lab/infra/terraform/terraform.tfvars`. Leave `available_tables = []` and `enabled_rules = ["legacy-auth-success"]` as they are. This file is git-ignored, so it never reaches GitHub.

📍 **Terminal**, in the **Terraform folder**:

```powershell
terraform plan -out tfplan
```

Read the plan in the Terminal before doing anything else. Nothing has been created yet. A green `+` next to a line means "will be created". You should see:

- `Plan: 3 to add, 0 to change, 0 to destroy.` The three are the resource group, the workspace and the Sentinel onboarding.
- **No** `azurerm_sentinel_alert_rule_scheduled`. The rule is held back.
- Under "Changes to Outputs": `skipped_rules` shows `legacy-auth-success` with `AADNonInteractiveUserSignInLogs` and `SigninLogs`, and `missing_tables` lists the same two tables.

📸 `04-plan-summary.png`: the **Terminal** showing the `Plan: 3 to add` line and the outputs with the skipped rule.

🗣 "Sentinel rejects a rule if its table doesn't exist yet. Instead of a failed deployment, the module holds the rule back and tells me which tables are missing, so I know which connector to enable next."

📍 **Terminal**, in the **Terraform folder**. This is the step that creates real resources in **Azure**:

```powershell
terraform apply tfplan
```

📸 `05-apply-complete.png`: the **Terminal** showing `Apply complete! Resources: 3 added` plus the outputs.

If apply fails with a message about a resource provider not being registered, run these in the same Terminal, wait a few minutes, then plan and apply again:

```powershell
az provider register --namespace Microsoft.SecurityInsights
az provider register --namespace Microsoft.OperationalInsights
```

## 7. Check it in the portal (10 min)

💡 **In plain words:** you walk through the building to confirm the builder did what the quote said. Everything you see here was created by the files, not by clicking.

📍 **Azure portal** (browser) for items 1 to 4.

1. Search bar → **Resource groups** → `rg-sentinel-lab`.
   📸 `06-resource-group.png`: the **browser** showing the resource list with `law-sentinel-lab`.
2. Click `law-sentinel-lab` → left menu **Settings → Usage and estimated costs** → **Daily cap** button at the top.
   📸 `07-daily-cap.png`: the **browser** showing the cap set to 1 GB/day.
3. Search bar → **Microsoft Sentinel** → click `law-sentinel-lab`. If Azure sends you to the Defender portal (<https://security.microsoft.com>), that is fine: Sentinel is under **Microsoft Sentinel** in its left menu.
   📸 `08-sentinel-overview.png`: the **browser** showing the Sentinel overview for the workspace.
4. In Sentinel's left menu: **Configuration → Analytics**.
   📸 `09-analytics-empty.png`: the **browser** showing no active rules yet, matching the plan.

📍 **Terminal**, in the **Terraform folder**, for item 5:

```powershell
terraform state list
terraform output
```

📸 `10-state-and-outputs.png`: the **Terminal** showing three resources in state and `skipped_rules` populated.

🗣 "Everything in that resource group came from code. Nothing was clicked."

## 8. Commit your evidence (5 min)

💡 **In plain words:** you save your proof (the screenshots) into the project's history and send it to GitHub. `git add` picks what to save, `git commit` saves it with a note, `git push` uploads it. GitHub's robots then re-run the checks from steps 2 and 3 on their own.

📍 **File Explorer or VS Code**: open `lab/evidence/lab-setup/` and look at each screenshot. Crop out any subscription ID, tenant ID or email address.

📍 **Terminal**. The first command takes you from the Terraform folder back to the **repo root**:

```powershell
cd ../../..
git status
git add lab/infra/terraform/.terraform.lock.hcl lab/evidence/lab-setup
git commit -m "Lab: add provider lock file and IaC deployment evidence"
git push
```

`git status` should list only the lock file and your screenshots as new. `terraform.tfvars`, `tfplan` and the `.terraform` folder must not appear in `git add`; if `tfplan` shows up, leave it out.

📍 **GitHub** (browser): open **Pull requests** → the open pull request → scroll to the checks box at the bottom and wait for `lab-validate` to go green.

📸 `11-pr-checks-green.png`: the **browser** showing the pull request's checks passing.

When you are happy with it, click **Merge pull request** on that same page.

## 9. Stretch: deploy your first rule (needs data, so probably tomorrow)

💡 **In plain words:** now you plug in the first camera (sign-in logs) and wait for footage to arrive. Once it does, you tell Terraform that the drawer for that footage exists, and it hands the guard the first instruction: "alert me when someone signs in using an old, weak sign-in method".

1. 📍 **Azure portal** → Microsoft Sentinel → `law-sentinel-lab` → **Content management → Content hub** → search **Microsoft Entra ID** → **Install**. Then **Configuration → Data connectors** → **Microsoft Entra ID** → **Open connector page** → tick **Sign-in logs** and **Non-interactive user sign-in logs** → **Apply changes**. This needs an Entra ID P1/P2 licence in the same tenant as the subscription (the M365 E5 trial includes it) and the Security Administrator role. See [data-connectors.md](data-connectors.md).
   📸 `12-entra-connector.png`: the **browser** showing the connector as connected.
2. 📍 **Browser** (a private window): sign out and in to <https://myapps.microsoft.com> a few times, then wait. First data can take from 15 minutes up to a few hours.
3. 📍 **Azure portal** → Microsoft Sentinel → **General → Logs**. Run `SigninLogs | take 5`, then `AADNonInteractiveUserSignInLogs | take 5`. Both must return rows without a "could not resolve table" error.
   📸 `13-signinlogs-data.png`: the **browser** showing rows returned.
4. 📍 **VS Code**: in `lab/infra/terraform/terraform.tfvars` set:

```hcl
available_tables = ["SigninLogs", "AADNonInteractiveUserSignInLogs"]
enabled_rules    = ["legacy-auth-success"]
```

5. 📍 **Terminal**, in the **Terraform folder**. If this is a new Terminal window, first repeat the last line of step 4 and the `terraform init` command from step 5 with your storage account name. Then run `terraform plan -out tfplan`, which should now show `1 to add` (the analytics rule), and `terraform apply tfplan`.
   📸 `14-plan-one-rule.png`: the **Terminal** showing `1 to add`.
6. 📍 **Azure portal** → Microsoft Sentinel → **Configuration → Analytics**.
   📸 `15-rule-in-analytics.png`: the **browser** showing the rule listed and enabled.
7. 📍 **VS Code**: remove the `enabled_rules` line from `terraform.tfvars`, then plan and apply again in the **Terminal** to deploy the other four sign-in rules.

## 10. Clean up when you're done practising

💡 **In plain words:** demolition. One command removes everything Terraform built, so nothing keeps costing money. Because the plan is saved in files, you can rebuild the same thing any time.

📍 **Terminal**, in the **Terraform folder**:

```powershell
terraform destroy
```

Read the list in the Terminal, then type `yes`. This deletes `rg-sentinel-lab`, the workspace and its data in **Azure**. You can rebuild it with `terraform apply` in a few minutes, which is the point of infrastructure as code.

📍 **Azure portal** → **Resource groups**: confirm `rg-sentinel-lab` is gone. Leave `rg-tfstate` in place; it costs almost nothing and holds your state.

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
