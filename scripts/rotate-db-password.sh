#!/usr/bin/env bash
# Part C (controlled demonstration): rotate the PostgreSQL admin password and prove the old one is rejected.
# The deployed Function App is the database client, so no firewall opening and no password leaves Azure:
#   1. health=ok with the current password (from Key Vault)
#   2. rotate the server password only -> the app still holds the OLD value -> health shows database=false
#      (App Insights logs: health check 'database' failed: 28P01 = invalid_password)
#   3. store the NEW value in Key Vault and force the Key Vault reference to re-resolve -> health=ok
#      (a restart alone serves the cached value; a config change triggers re-resolution, so a
#       temporary marker setting is added and removed, leaving settings identical to Terraform)
# The new value exists only in this shell's memory; nothing is printed or written to disk.
set -euo pipefail
RG="${RESOURCE_GROUP:-rg-molyslog}"

KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv)
PG=$(az postgres flexible-server list -g "$RG" --query "[0].name" -o tsv)
FUNC=$(az functionapp list -g "$RG" --query "[0].name" -o tsv)
API=$(az functionapp show -g "$RG" -n "$FUNC" --query properties.defaultHostName -o tsv)

health() { curl -s -m 60 -w ' (HTTP %{http_code})' "https://$API/api/health"; echo; }
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

echo "[$(stamp)] 1) Before rotation:"; health

NEW=$(openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-32)
echo "[$(stamp)] 2) Rotating the server admin password (Key Vault still holds the old value)"
az postgres flexible-server update -g "$RG" -n "$PG" --admin-password "$NEW" --only-show-errors -o none
echo "[$(stamp)]    App now authenticates with the OLD password (expected: database=false):"
health; sleep 20; health

echo "[$(stamp)] 3) Storing the new value in Key Vault and restarting the app"
az keyvault secret set --vault-name "$KV" -n db-admin-password --value "$NEW" --content-type "PostgreSQL admin password" --only-show-errors -o none
unset NEW
az functionapp config appsettings set -g "$RG" -n "$FUNC" --settings KV_REFRESH_MARKER=1 -o none --only-show-errors
az functionapp config appsettings delete -g "$RG" -n "$FUNC" --setting-names KV_REFRESH_MARKER -o none --only-show-errors
for i in $(seq 1 10); do sleep 30; OUT=$(health); echo "[$(stamp)]    $OUT"; [[ "$OUT" == *'"status":"ok"'* ]] && break; done
echo "Key Vault versions of db-admin-password (names/dates only):"
az keyvault secret list-versions --vault-name "$KV" -n db-admin-password --query "sort_by(@,&attributes.created)[].{created:attributes.created,enabled:attributes.enabled}" -o table
