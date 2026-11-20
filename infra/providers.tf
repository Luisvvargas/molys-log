terraform {
  required_version = ">= 1.11.0" # write-only attributes keep the DB password out of state

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }

  # Local state (gitignored). For team use, move to an azurerm backend with Entra ID auth.
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id     = var.subscription_id
  storage_use_azuread = true # storage data-plane calls use Entra ID, not account keys

  # Providers are registered explicitly (az provider register) so plan never modifies the subscription.
  resource_provider_registrations = "none"
}
