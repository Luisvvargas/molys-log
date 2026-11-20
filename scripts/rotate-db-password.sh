#!/usr/bin/env bash
# Part C: rotate the PostgreSQL admin password and prove the old one is rejected.
# The old and new values exist only in shell memory; nothing is printed or written to disk.
# Requires: az (Key Vault Secrets Officer on the vault), psql, your IP allowed by the PG firewall.
set -euo pipefail
RG="${RESOURCE_GROUP:-rg-molyslog}"

KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv)
PG=$(az postgres flexible-server list -g "$RG" --query "[0].name" -o tsv)
PG_HOST=$(az postgres flexible-server show -g "$RG" -n "$PG" --query fullyQualifiedDomainName -o tsv)
PG_USER=$(az postgres flexible-server show -g "$RG" -n "$PG" --query administratorLogin -o tsv)
FUNC=$(az functionapp list -g "$RG" --query "[0].name" -o tsv)

try_login() { PGPASSWORD="$1" psql "host=$PG_HOST dbname=postgres user=$PG_USER sslmode=require connect_timeout=10" -c 'select 1' >/dev/null; }

OLD=$(az keyvault secret show --vault-name "$KV" -n db-admin-password --query value -o tsv)
echo "1) Old password authenticates before rotation:"; try_login "$OLD" && echo "   OK"

NEW=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
echo "2) Rotating server password and Key Vault secret"
az postgres flexible-server update -g "$RG" -n "$PG" --admin-password "$NEW" --only-show-errors >/dev/null
az keyvault secret set --vault-name "$KV" -n db-admin-password --value "$NEW" --only-show-errors >/dev/null
unset NEW
az functionapp restart -g "$RG" -n "$FUNC" # re-resolve the Key Vault reference

echo "3) Old password after rotation (expected failure):"
if try_login "$OLD"; then echo "   UNEXPECTED: old password still works" >&2; unset OLD; exit 1; fi
unset OLD
echo "   Rejected as expected. Run scripts/verify.sh to confirm the app works with the new value."
