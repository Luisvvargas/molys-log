# Status — Moly's Log

_Last updated: 2026-11-19_

## Target subscription
Luis's Azure for Students (Enabled, spending limit On). Octavio's subscription is **Disabled** (no credit) — not usable.
Project lives in `~/dev/molys_log` (the iCloud copy in `~/Documents` is abandoned, untouched).

## Completed (local)
- Terraform (`infra/`): RG, Log Analytics + App Insights, Storage (keys disabled) + `app-package` + `pet-documents`, Key Vault (RBAC), PostgreSQL Flexible B1ms v16 + DB + firewall, Functions Flex Consumption (Node 22, system identity, Key Vault reference, CORS = frontend origin only), role assignments, `id-github-actions` UAMI (Contributor on RG, Blob Data Contributor) + federated credential (main only).
- Frontend hosting flag `frontend_hosting`: `swa` (intended, retained) | `blob` (Storage static website, deployable fallback). Same React build.
- DB password: ephemeral + write-only → never in state/plan; only in Key Vault `db-admin-password`.
- `resource_provider_registrations = "none"`: Terraform never registers providers.
- Scripts auto-detect SWA vs static website. Workflows: `ci.yml`, `deploy.yml` (OIDC).

## Test results (2026-11-19)
| Check | Result |
|---|---|
| `terraform fmt -check`, `validate` | Pass |
| `terraform plan` blob mode (Luis's sub, read-only) | 24 to add, 0 errors |
| `terraform plan` swa mode (Luis's sub, read-only) | 24 to add, 0 errors (apply would be denied by region policy) |
| Invalid `frontend_hosting` value | Rejected by variable validation |
| Plan output | Contains no password values |
| API unit tests / frontend build / npm audit | 3/3 pass / OK / 0 vulns |
| Gitleaks full history + manual checks | No findings |

## Azure findings (Luis's subscription)
- Policy *Allowed resource deployment regions* (deny): westus, northcentralus, mexicocentral, brazilsouth, canadacentral → **no SWA region** → SWA blocked. Region used: westus.
- PostgreSQL B1ms and Flex Consumption (Node 22) available in westus.
- `Microsoft.DBforPostgreSQL` **NotRegistered** → must be registered before apply (needs approval).
- Not verified until apply: PostgreSQL provisioning quota in westus; static website data-plane permission for the deployer.

## Pre-deployment audit (2026-11-19, read-only)
- Target: Luis's subscription …04c0 (Enabled); CLI default and `terraform.tfvars` match. `rg-molyslog` does not exist yet. Region `westus`, `frontend_hosting = "blob"`.
- Permissions: Owner (unconditional, actions `*`), no deny assignments → provider registration and the 6 planned role assignments are permitted. Policies: allowed-regions (deny; westus allowed) and Microsoft cloud security benchmark (audit only).
- PostgreSQL B1ms in westus: not restricted for this subscription; vCPU quota 0/6 used.
- Free allowance: official Azure for Students pages (offer page, free-services page) do **not** confirm free PostgreSQL hours for this offer → treated as **billable**.
- `.gitignore` verified: tfstate, tfvars, tfplan, `.env*`, `local.settings.json`, `security/`, `gitleaks*.json`, zips ignored; nothing sensitive tracked.
- **Required input:** `github_repository` is still a placeholder → must be set before apply or the OIDC federated credential trusts the wrong repo.

## Estimated cost of this deployment (USD/month, Retail Prices API, westus)
| Item | Basis | Est. |
|---|---|---|
| PostgreSQL B1ms compute | 0.022/h × 730 h | 16.06 |
| PostgreSQL storage 32 GB | ~0.115/GB-mo (published) | ~3.70 |
| PostgreSQL backup (7 days, LRS) | free up to provisioned size | ~0 |
| Functions Flex Consumption | on-demand free grant; health checks only | ~0 |
| Storage (packages, docs, `$web`) | < 1 GB LRS + few ops | < 0.10 |
| Key Vault Standard | 0.03 / 10k ops | < 0.05 |
| App Insights / Log Analytics | 5 GB/mo free; cap 0.5 GB/day | ~0 |
| SWA / identities / role assignments / RG | not created (blob mode) / free | 0 |
| **Total** | | **≈ 20 (≈ 0.66/day)**; stopping PostgreSQL when idle removes compute cost |

## Other resources consuming credit (read-only, nothing modified)
| Resource | RG | State | Est. USD/mo | Removable if ZavaShop no longer needed |
|---|---|---|---|---|
| Standard Load Balancer `kubernetes` | MC_rg-zavashop-luis… | exists (AKS stopped) | ~18 | Yes — by deleting the AKS cluster, never directly |
| 2× Standard public IP | MC_rg-zavashop-luis… | allocated | 7.30 | Yes — same (AKS-managed) |
| ACR Basic | rg-zavashop-luis | exists | 5.07 | Yes |
| ACR Basic (not ZavaShop) | rg-aks-tarea-luis-1027 | exists | 5.07 | Only if that homework is done |
| AKS `aks-zavashop-luis` (Free tier, D4s_v4) | rg-zavashop-luis | Stopped, 0 nodes | ~0 | Yes |
| 8 Container Apps + 2 envs (Consumption) | rg-zavashop-luis | Stopped | ~0 | Yes |
| Key Vault, Log Analytics, identities, DCR | rg-zavashop-luis | idle | ~0 | Yes |
| AI Services S0 (gpt-5-mini, pay-per-token) | rg-aks-tarea-luis-1027 | idle | ~0 | Only if that homework is done |
ZavaShop idle cost ≈ USD 30/month. Cleanest removal (user decision): delete `rg-zavashop-luis` (also removes the AKS-managed MC_ group). Cost Management API returned no rows; confirm in the portal.

## Outstanding
- Repository: `Luisvvargas/molys-log` (public; not yet created — GitHub API 404 on 2026-11-19). Plan re-run: federated subject `repo:Luisvvargas/molys-log:ref:refs/heads/main`.
- Approval: register `Microsoft.DBforPostgreSQL`; `terraform apply` (blob mode); create + push GitHub repo.
- Second Draft: apply → deploy → verify → evidence.
- Lab A: rescan after push. Lab B: Key Vault evidence after apply. Lab C: nothing exposed → report honestly; optional demo needs approval. Lab D: GitHub secrets + main run + `test-oidc` negative run.
- PDF report (must state SWA deviation).
