data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result
  tags = {
    project = var.project
    course  = "cetys-cloud-computing"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}"
  location = var.location
  tags     = local.tags
}

# ---------- Monitoring ----------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project}-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.5 # cost guard
  tags                = local.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project}-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

# ---------- Storage (Functions host + pet document blobs) ----------
resource "azurerm_storage_account" "main" {
  name                            = "st${var.project}${local.suffix}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # identity-only access; no account keys to leak
  tags                            = local.tags
}

resource "azurerm_storage_container" "deployments" {
  name                  = "app-package"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
  depends_on            = [time_sleep.rbac_propagation]
}

resource "azurerm_storage_container" "documents" {
  name                  = "pet-documents"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
  depends_on            = [time_sleep.rbac_propagation]
}

# ---------- Key Vault (RBAC mode) ----------
resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.project}-${local.suffix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # allows cleanup at course end
  tags                       = local.tags
}

# Administrator (whoever runs Terraform): manage secrets.
resource "azurerm_role_assignment" "admin_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Administrator: create blob containers over Entra ID (account keys are disabled).
resource "azurerm_role_assignment" "admin_blob" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "rbac_propagation" {
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.admin_kv_officer, azurerm_role_assignment.admin_blob]
}

# ---------- PostgreSQL Flexible Server ----------
# Ephemeral + write-only: the password is never stored in Terraform state or plan.
ephemeral "random_password" "db_admin" {
  length           = 32
  special          = true
  override_special = "-_.~"
}

resource "azurerm_key_vault_secret" "db_admin_password" {
  name             = "db-admin-password"
  key_vault_id     = azurerm_key_vault.main.id
  value_wo         = ephemeral.random_password.db_admin.result
  value_wo_version = var.db_password_version
  content_type     = "PostgreSQL admin password"
  depends_on       = [time_sleep.rbac_propagation]
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                              = "psql-${var.project}-${local.suffix}"
  location                          = azurerm_resource_group.main.location
  resource_group_name               = azurerm_resource_group.main.name
  version                           = "16"
  sku_name                          = var.postgres_sku
  storage_mb                        = 32768
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  public_network_access_enabled     = true
  administrator_login               = var.db_admin_login
  administrator_password_wo         = ephemeral.random_password.db_admin.result
  administrator_password_wo_version = var.db_password_version
  tags                              = local.tags

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.project
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# 0.0.0.0 = "Allow Azure services" (Functions outbound IPs are dynamic on Flex Consumption).
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ---------- Frontend hosting (same React build for both options) ----------
# "swa"  = intended architecture (Azure Static Web Apps, required by the course).
# "blob" = fallback when a subscription policy blocks every SWA region (see README).
resource "azurerm_static_web_app" "main" {
  count               = var.frontend_hosting == "swa" ? 1 : 0
  name                = "stapp-${var.project}-${local.suffix}"
  location            = var.swa_location
  resource_group_name = azurerm_resource_group.main.name
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = local.tags
}

# Static website on the existing storage account: served from the $web container
# over the public web endpoint; the account itself stays key-less and non-public.
resource "azurerm_storage_account_static_website" "frontend" {
  count              = var.frontend_hosting == "blob" ? 1 : 0
  storage_account_id = azurerm_storage_account.main.id
  index_document     = "index.html"
  error_404_document = "index.html" # SPA fallback for client-side routes
}

locals {
  frontend_origin = (var.frontend_hosting == "swa"
    ? "https://${azurerm_static_web_app.main[0].default_host_name}"
  : trimsuffix(azurerm_storage_account.main.primary_web_endpoint, "/"))
}

# ---------- Azure Functions (REST API, Flex Consumption) ----------
resource "azurerm_service_plan" "func" {
  name                = "asp-${var.project}-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "api" {
  name                        = "func-${var.project}-${local.suffix}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  service_plan_id             = azurerm_service_plan.func.id
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.deployments.name}"
  storage_authentication_type = "SystemAssignedIdentity"
  runtime_name                = "node"
  runtime_version             = "22"
  maximum_instance_count      = 40
  instance_memory_in_mb       = 2048
  https_only                  = true

  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    cors {
      allowed_origins = [local.frontend_origin, "http://localhost:5173"]
    }
  }

  app_settings = {
    AzureWebJobsStorage__accountName = azurerm_storage_account.main.name
    AzureWebJobsStorage__credential  = "managedidentity"
    DB_HOST                          = azurerm_postgresql_flexible_server.main.fqdn
    DB_NAME                          = azurerm_postgresql_flexible_server_database.app.name
    DB_USER                          = var.db_admin_login
    # Key Vault reference: resolved by the platform using the app's managed identity.
    DB_PASSWORD          = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=${azurerm_key_vault_secret.db_admin_password.name})"
    STORAGE_ACCOUNT_NAME = azurerm_storage_account.main.name
    DOCUMENTS_CONTAINER  = azurerm_storage_container.documents.name
  }

  tags = local.tags
}

# Application identity: read secrets only (least privilege).
resource "azurerm_role_assignment" "func_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.api.identity[0].principal_id
}

# Host storage + document blobs via identity.
resource "azurerm_role_assignment" "func_blob_owner" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.api.identity[0].principal_id
}

# ---------- GitHub Actions OIDC (user-assigned managed identity) ----------
resource "azurerm_user_assigned_identity" "github" {
  name                = "id-github-actions"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "github_rg_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

# The pipeline uploads the Functions package to the deployment container.
resource "azurerm_role_assignment" "github_blob" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_federated_identity_credential" "github_main" {
  name      = "github-${var.github_branch}"
  parent_id = azurerm_user_assigned_identity.github.id
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
  audience  = ["api://AzureADTokenExchange"]
}
