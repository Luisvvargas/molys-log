#!/usr/bin/env bash
# Deploys the API (Functions) and frontend (Static Web Apps) code to existing infrastructure.
# Requires an authenticated az session (local `az login` or azure/login OIDC in CI).
# No credentials are stored: the SWA deployment token is fetched at runtime and never printed.
set -euo pipefail

RG="${RESOURCE_GROUP:-rg-molyslog}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

FUNC=$(az functionapp list -g "$RG" --query "[0].name" -o tsv)
SWA=$(az staticwebapp list -g "$RG" --query "[0].name" -o tsv)
[[ -n "$FUNC" && -n "$SWA" ]] || { echo "Function App or Static Web App not found in $RG" >&2; exit 1; }
API_HOST=$(az functionapp show -g "$RG" -n "$FUNC" --query defaultHostName -o tsv)

echo "==> Packaging API"
pushd "$ROOT/api" >/dev/null
npm ci --omit=dev --no-audit --no-fund
rm -f api.zip && zip -qr api.zip host.json package.json src node_modules
popd >/dev/null

echo "==> Deploying API to $FUNC"
az functionapp deployment source config-zip -g "$RG" -n "$FUNC" --src "$ROOT/api/api.zip" --only-show-errors >/dev/null

echo "==> Building frontend"
pushd "$ROOT/frontend" >/dev/null
npm ci --no-audit --no-fund
VITE_API_BASE_URL="https://$API_HOST" npm run build
popd >/dev/null

echo "==> Deploying frontend to $SWA"
SWA_TOKEN=$(az staticwebapp secrets list -g "$RG" -n "$SWA" --query properties.apiKey -o tsv)
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::add-mask::$SWA_TOKEN"; fi
npx -y @azure/static-web-apps-cli@2 deploy "$ROOT/frontend/dist" \
  --deployment-token "$SWA_TOKEN" --env production >/dev/null
unset SWA_TOKEN

echo "==> Done. Run scripts/verify.sh to check connectivity."
