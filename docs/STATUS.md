# Status — Moly's Log

_Last updated: 2026-11-19_

## Location
Project rebuilt in `~/dev/molys_log` (outside iCloud). The original `~/Documents/molys_log` copy had its files and `.git` evicted to iCloud as cloud-only placeholders; it is left untouched and is no longer used. Git history restarts here (the previous 2 local commits were never pushed).

## Completed (local)
- Terraform (`infra/`): RG, Log Analytics + App Insights, Storage (keys disabled) + 2 containers, Key Vault (RBAC), PostgreSQL Flexible B1ms + DB + firewall, SWA Free, Functions Flex Consumption (Node 22, system identity, Key Vault reference), role assignments, `id-github-actions` UAMI + Contributor on RG + federated credential (main only). Region: **centralus**.
- DB admin password: ephemeral `random_password` + write-only attributes → never in state/plan; stored only in Key Vault `db-admin-password`.
- `resource_provider_registrations = "none"`: plan never modifies the subscription.
- Boilerplate: `api/` GET `/api/health`; `frontend/` React health page.
- Scripts: `deploy.sh`, `verify.sh`, `scan-secrets.sh`, `rotate-db-password.sh`. Workflows: `ci.yml`, `deploy.yml` (OIDC).

## Test results (local, 2026-11-19)
| Check | Result |
|---|---|
| `terraform fmt -check` / `validate` (azurerm 4.81.0, TF 1.17.2) | Pass |
| API unit tests | 3/3 pass |
| Frontend build | OK |
| `npm audit` api (prod) / frontend | 0 vulnerabilities |
| Shell syntax, all scripts | OK |
| Gitleaks full history (1 commit) + manual checks | No findings |
| `terraform plan` | **Not run** — target subscription is Disabled (see Azure findings) |

## Azure findings (Octavio's Azure for Students subscription)
- **BLOCKER: subscription state = Disabled** (ARM, 2026-11-19; offer AzureForStudents, spending limit On). Typical causes: $100 credit used up or 12-month term expired. Disabled subscriptions are read-only; no resources can be created.
- Signed in as Octavio's own account (Owner). Luis has no delegated role on it yet.
- An unrelated AKS cluster (`rg-aks-lab2`) in this subscription may have consumed the credit.
- Policy "Allowed resource deployment regions": westus, brazilsouth, northcentralus, mexicocentral, centralus → everything in **centralus** (only overlap with SWA regions).
- PostgreSQL B1ms available in centralus; Flex Consumption supports Node 20/22/24 there.
- `Microsoft.DBforPostgreSQL` provider **NotRegistered** (needs `az provider register`, free; requires approval).

## Estimated cost (USD/month)
PostgreSQL B1ms + 32 GB ≈ 15–17 (dominant; can be stopped when idle). Functions Flex, SWA Free, Key Vault, identities ≈ 0. Storage, Log Analytics (0.5 GB/day cap) < 1.

## Outstanding
- Second Draft: `terraform plan` → apply (needs approval) → deploy → verify; create/push GitHub repo.
- Lab A: rescan after publishing; report "no findings" truthfully (new repo).
- Lab B: Key Vault/identity evidence after apply.
- Lab C: no exposed credentials → nothing to rotate; optional demo via `rotate-db-password.sh` needs approval.
- Lab D: GitHub secrets, successful run on main, failing run from `test-oidc`.
- PDF report.
