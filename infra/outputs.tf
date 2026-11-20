output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "function_app_name" {
  value = azurerm_function_app_flex_consumption.api.name
}

output "api_base_url" {
  value = "https://${azurerm_function_app_flex_consumption.api.default_hostname}"
}

output "frontend_hosting" {
  value = var.frontend_hosting
}

output "static_web_app_name" {
  value = one(azurerm_static_web_app.main[*].name)
}

output "frontend_url" {
  value = local.frontend_origin
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.main.name
}

# Not secrets: values for the GitHub Actions secrets/variables used by azure/login (OIDC).
output "github_oidc_client_id" {
  value = azurerm_user_assigned_identity.github.client_id
}
