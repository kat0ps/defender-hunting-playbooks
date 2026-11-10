# Declares which provider this module needs. The version itself is pinned once in the root
# module (providers.tf); child modules only say "I need azurerm" so they inherit that pin.
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}
