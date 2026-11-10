# providers.tf: which Terraform version and which providers (Azure plugins) this lab uses.
# Pinning versions means the same code gives the same result on your laptop and in GitHub Actions.
# The exact provider versions that were downloaded are recorded in .terraform.lock.hcl. Commit that
# file so CI uses the same versions.

terraform {
  # 1.6+ for check blocks (used in the sentinel module) and current azurerm 4.x support.
  required_version = ">= 1.6.0"

  required_providers {
    # azurerm manages Azure resources: resource group, workspace, Sentinel, analytics rules.
    # "~> 4.0" = any 4.x release, never 5.0 (a major version can contain breaking changes).
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # azuread manages Entra ID objects (app registrations, groups). Nothing uses it yet; it's declared
    # now for the GitHub Actions OIDC app registration in Phase 4.
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

# azurerm 4.x requires a subscription ID. It's deliberately NOT written here (never commit IDs):
# set the ARM_SUBSCRIPTION_ID environment variable locally, or as a GitHub secret in the workflows.
# Sign-in comes from `az login` locally and from OIDC (ARM_USE_OIDC=true) in GitHub Actions.
provider "azurerm" {
  features {}
}

# Tenant comes from ARM_TENANT_ID / az login, same as above.
provider "azuread" {}
