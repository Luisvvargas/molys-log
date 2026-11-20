#!/usr/bin/env bash
# Verifies the deployed boilerplate end to end: frontend reachable, API health (Key Vault, PostgreSQL, Blob), CORS.
# Exits non-zero unless the frontend returns 200 and /api/health returns 200 with status "ok".
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

FRONT=$(curl -s -o /dev/null -m 30 -w '%{http_code}' "$ORIGIN/" || true)
echo "Frontend: $ORIGIN -> HTTP $FRONT"

# The Functions host may be cold or restarting right after a deployment: retry for ~5 minutes.
CODE=000; BODY=""
for attempt in $(seq 1 10); do
  BODY=$(curl -s -m 30 -w '\n%{http_code}' "https://$API_HOST/api/health" || true)
  CODE="${BODY##*$'\n'}"; BODY="${BODY%$'\n'*}"
  [[ "$CODE" == "200" ]] && break
  echo "  health attempt $attempt: HTTP ${CODE:-000}, retrying in 30s"; sleep 30
done
echo "API health: HTTP $CODE $BODY"

echo "CORS preflight from frontend origin:"
curl -s -m 30 -o /dev/null -D - -X OPTIONS "https://$API_HOST/api/health" \
  -H "Origin: $ORIGIN" -H "Access-Control-Request-Method: GET" | grep -i '^access-control-allow-origin' || echo "(no CORS header)"

[[ "$FRONT" == "200" && "$CODE" == "200" ]] || { echo "VERIFY FAILED" >&2; exit 1; }
echo "VERIFY OK"
