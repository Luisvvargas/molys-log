#!/usr/bin/env bash
# Verifies the deployed boilerplate end to end: frontend reachable, API health (Key Vault, PostgreSQL, Blob), CORS.
set -euo pipefail
RG="${RESOURCE_GROUP:-rg-molyslog}"

FUNC=$(az functionapp list -g "$RG" --query "[0].name" -o tsv)
API_HOST=$(az functionapp show -g "$RG" -n "$FUNC" --query defaultHostName -o tsv)
SWA_HOST=$(az staticwebapp list -g "$RG" --query "[0].defaultHostname" -o tsv 2>/dev/null || true)
if [[ -n "$SWA_HOST" ]]; then
  ORIGIN="https://$SWA_HOST"; echo "Frontend host: Static Web Apps"
else
  ST=$(az storage account list -g "$RG" --query "[0].name" -o tsv)
  ORIGIN=$(az storage account show -g "$RG" -n "$ST" --query primaryEndpoints.web -o tsv); ORIGIN="${ORIGIN%/}"
  echo "Frontend host: Storage static website (fallback; SWA blocked by subscription policy)"
fi

echo "Frontend: $ORIGIN -> HTTP $(curl -s -o /dev/null -w '%{http_code}' "$ORIGIN/")"
echo "API health:"
curl -s -w '\nHTTP %{http_code}\n' "https://$API_HOST/api/health"
echo "CORS preflight from frontend origin:"
curl -s -o /dev/null -D - -X OPTIONS "https://$API_HOST/api/health" \
  -H "Origin: $ORIGIN" -H "Access-Control-Request-Method: GET" | grep -i '^access-control-allow-origin' || echo "(no CORS header)"
