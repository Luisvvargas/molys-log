#!/usr/bin/env bash
# Part A: full-history Gitleaks scan + manual checks for files gitleaks may miss.
# Reports are redacted and written to security/ (gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-security/gitleaks-before.json}"
mkdir -p security

echo "Commits scanned: $(git rev-list --all --count)"
gitleaks git . -v --redact --report-format json --report-path "$OUT" && echo "Gitleaks: no findings" || echo "Gitleaks: findings written to $OUT"

echo "Sensitive files ever committed (.env, tfstate, tfvars, appsettings, local.settings):"
git log --all --name-only --pretty=format: | sort -u | grep -E '(^|/)(\.env$|.*\.tfstate|.*\.tfvars$|appsettings.*\.json|local\.settings\.json)' || echo "  none"

echo "Hardcoded password/key patterns in IaC and scripts (tracked files):"
git grep -nIiE '(password|secret|access_key|connection_string)\s*[:=]\s*"[^"$@{]{6,}' -- infra scripts .github || echo "  none"
