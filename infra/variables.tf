variable "subscription_id" {
  description = "Target Azure subscription (team's Azure for Students subscription)."
  type        = string
}

variable "project" {
  description = "Short project name used in resource names."
  type        = string
  default     = "molyslog"
}

variable "location" {
  description = "Region for Functions, PostgreSQL, Storage, Key Vault and monitoring."
  type        = string
  default     = "westus" # Luis's subscription policy allows: westus, northcentralus, mexicocentral, brazilsouth, canadacentral
}

variable "frontend_hosting" {
  description = "Frontend host: \"swa\" (intended, Azure Static Web Apps) or \"blob\" (Storage static website fallback)."
  type        = string
  default     = "swa"
  validation {
    condition     = contains(["swa", "blob"], var.frontend_hosting)
    error_message = "frontend_hosting must be \"swa\" or \"blob\"."
  }
}

variable "swa_location" {
  description = "Static Web Apps region (SWA offers: westus2, centralus, eastus2, westeurope, eastasia)."
  type        = string
  default     = "centralus" # used only when frontend_hosting = "swa"
}

variable "github_repository" {
  description = "GitHub repository as owner/name, trusted by the OIDC federated credential."
  type        = string
}

variable "github_branch" {
  description = "Only this branch may authenticate to Azure from GitHub Actions."
  type        = string
  default     = "main"
}

variable "db_admin_login" {
  description = "PostgreSQL administrator login name (not a secret)."
  type        = string
  default     = "molysadmin"
}

variable "db_password_version" {
  description = "Increment to generate and apply a new PostgreSQL admin password (rotation)."
  type        = number
  default     = 1
}

variable "postgres_location" {
  description = "Region for PostgreSQL; empty = same as location. Some student subscriptions get SkuNotAvailable for B1ms in a region."
  type        = string
  default     = ""
}

variable "postgres_sku" {
  description = "PostgreSQL Flexible Server SKU. B_Standard_B1ms is the cheapest burstable tier."
  type        = string
  default     = "B_Standard_B1ms"
}
