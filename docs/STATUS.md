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

## Existing resources consuming credit (read-only inspection, nothing modified)
| Resource | State | Ongoing cost (approx.) |
|---|---|---|
| AKS `aks-zavashop-luis` (Free tier, 1× D4s_v4) | Stopped, VMSS 0 instances | ~0 compute |
| 2× Standard public IP (MC_ RG) | Allocated | ~USD 3.6/mo each |
| Standard Load Balancer `kubernetes` (1 rule + 1 outbound) | Exists | ~USD 18/mo if billed while stopped |
| 2× ACR Basic (zavashop, aks-tarea) | Exists | ~USD 5/mo each |
| 8 Container Apps (min replicas 1) | Stopped | ~0 while stopped |
| Cognitive Services S0 (aks-tarea) | Exists | pay-per-use |
| 3× Log Analytics workspaces | Exist | ingestion-based |
Cost Management query returned no cost rows (Azure for Students often doesn't expose it via API); check the portal for exact figures.

## Estimated cost of this deployment (USD/month)
PostgreSQL B1ms + 32 GB ≈ 15–17 (stop when idle). Functions Flex, static website, Key Vault, identities ≈ 0. Storage, Log Analytics (0.5 GB/day cap) < 1.

## Outstanding
- Approval: register `Microsoft.DBforPostgreSQL`; `terraform apply` (blob mode); create + push GitHub repo (need owner/name).
- Second Draft: apply → deploy → verify → evidence.
- Lab A: rescan after push. Lab B: Key Vault evidence after apply. Lab C: nothing exposed → report honestly; optional demo needs approval. Lab D: GitHub secrets + main run + `test-oidc` negative run.
- PDF report (must state SWA deviation).
