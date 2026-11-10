# This module needs the azurerm provider; the version is pinned once in the root providers.tf.
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}
