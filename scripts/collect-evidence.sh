#!/usr/bin/env bash
# Collects Security Lab / Second Draft evidence into security/evidence/ (gitignored).
# Only names, roles, states and setting *shapes* are recorded; secret values are never read or printed.
set -uo pipefail
cd "$(dirname "$0")/.."
RG="${RESOURCE_GROUP:-rg-molyslog}"; REPO="${REPO:-Luisvvargas/molys-log}"
OUT=security/evidence; mkdir -p "$OUT"
mask() { sed -E 's#/subscriptions/[0-9a-f-]+#/subscriptions/<sub>#g'; }

KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv)
FUNC=$(az functionapp list -g "$RG" --query "[0].name" -o tsv)

{ echo "# Resources in $RG"; az resource list -g "$RG" --query "sort_by(@,&type)[].[type,name,location]" -o tsv; } > "$OUT/resources.txt"

{ echo "# Key Vault $KV"; az keyvault show -n "$KV" --query "{name:name,rbacAuthorization:properties.enableRbacAuthorization,softDeleteDays:properties.softDeleteRetentionInDays,sku:properties.sku.name}" -o table
  echo; echo "# Secret names (values never read)"; az keyvault secret list --vault-name "$KV" --query "[].{name:name,contentType:contentType,enabled:attributes.enabled,updated:attributes.updated}" -o table
  echo; echo "# db-admin-password versions"; az keyvault secret list-versions --vault-name "$KV" -n db-admin-password --query "sort_by(@,&attributes.created)[].{created:attributes.created,enabled:attributes.enabled}" -o table
} > "$OUT/keyvault.txt"

{ echo "# Role assignments in $RG (scope shortened)"
  az role assignment list --all --query "[?contains(scope,'$RG')].{role:roleDefinitionName,principalType:principalType,principal:principalId,scope:scope}" -o tsv \
    | awk -F'\t' '{n=split($4,a,"/"); printf "%-30s %-17s %-40s .../%s/%s\n",$1,$2,$3,a[n-1],a[n]}' | mask
} > "$OUT/rbac.txt"

{ echo "# Function App $FUNC identity and Key Vault reference"
  az functionapp identity show -g "$RG" -n "$FUNC" --query "{type:type}" -o table
  echo; echo "# App settings (names; DB_PASSWORD shows the reference string, not the secret)"
  az functionapp config appsettings list -g "$RG" -n "$FUNC" --query "[].{name:name,value:value}" -o tsv \
    | awk -F'\t' '{v=$2; if($1~/APPLICATIONINSIGHTS|AzureWebJobsStorage$/) v=(v==""?"<empty>":"<redacted>"); print $1" = "v}'
  echo; echo "# Key Vault reference resolution status"
  ID=$(az functionapp show -g "$RG" -n "$FUNC" --query id -o tsv)
  az rest --method get --url "https://management.azure.com$ID/config/configreferences/appsettings?api-version=2023-12-01" \
    --query "value[?name=='DB_PASSWORD'].{name:name,status:properties.status,details:properties.details}" -o table
} > "$OUT/function-app.txt"

{ echo "# GitHub OIDC identity"; az identity show -g "$RG" -n id-github-actions --query "{name:name,type:type}" -o table
  echo; echo "# Federated credentials"; az identity federated-credential list -g "$RG" --identity-name id-github-actions --query "[].{name:name,issuer:issuer,subject:subject,audiences:join(',',audiences)}" -o table
  echo; echo "# GitHub repository secrets (names only)"; gh secret list -R "$REPO"
  echo; echo "# Recent deploy runs"; gh run list -R "$REPO" -w deploy --limit 8 --json databaseId,headBranch,event,conclusion,createdAt,url -q '.[] | "\(.createdAt) \(.headBranch) \(.event) \(.conclusion) \(.url)"'
} > "$OUT/oidc.txt" 2>&1

{ echo "# PostgreSQL"; az postgres flexible-server show -g "$RG" -n "$(az postgres flexible-server list -g "$RG" --query '[0].name' -o tsv)" --query "{name:name,location:location,sku:sku.name,version:version,state:state,publicAccess:network.publicNetworkAccess}" -o table
  echo; echo "# Firewall rules"; az postgres flexible-server firewall-rule list -g "$RG" -s "$(az postgres flexible-server list -g "$RG" --query '[0].name' -o tsv)" --query "[].{name:name,start:startIpAddress,end:endIpAddress}" -o table
} > "$OUT/postgres.txt"

echo "Evidence written to $OUT:"; ls -1 "$OUT"
