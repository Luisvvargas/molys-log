#!/usr/bin/env bash
# Verifies the deployed boilerplate end to end: frontend reachable, API health (Key Vault, PostgreSQL, Blob).
set -euo pipefail
RG="${RESOURCE_GROUP:-rg-molyslog}"

FUNC=$(az functionapp list -g "$RG" --query "[0].name" -o tsv)
API_HOST=$(az functionapp show -g "$RG" -n "$FUNC" --query defaultHostName -o tsv)
SWA_HOST=$(az staticwebapp list -g "$RG" --query "[0].defaultHostname" -o tsv)

echo "Frontend: https://$SWA_HOST -> HTTP $(curl -s -o /dev/null -w '%{http_code}' "https://$SWA_HOST")"
echo "API health:"
curl -s -w '\nHTTP %{http_code}\n' "https://$API_HOST/api/health"
echo "CORS preflight from frontend origin:"
curl -s -o /dev/null -D - -X OPTIONS "https://$API_HOST/api/health" \
  -H "Origin: https://$SWA_HOST" -H "Access-Control-Request-Method: GET" | grep -i '^access-control-allow-origin' || echo "(no CORS header)"
