# backend.tf: where Terraform keeps its state file (its record of what it created in Azure).
# Remote state in an Azure Storage account means your laptop and GitHub Actions share one state,
# and the blob lease stops two runs from changing the lab at the same time.
#
# The block is empty on purpose ("partial configuration"): the storage account details are passed at
# init time so no names or IDs are committed:
#
#   terraform init \
#     -backend-config="resource_group_name=<state-rg>" \
#     -backend-config="storage_account_name=<state-storage-account>" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=sentinel-lab.tfstate" \
#     -backend-config="use_azuread_auth=true"
#
# For a quick offline check (no Azure access) use: terraform init -backend=false && terraform validate
terraform {
  backend "azurerm" {}
}
