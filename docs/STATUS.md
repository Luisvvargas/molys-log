# Status — Moly's Log

_Last updated: 2026-11-20_

Repository: https://github.com/Luisvvargas/molys-log (public). Subscription: Luis's Azure for Students (Octavio's is disabled — no credit).

## Second Draft — complete (with one documented deviation)
| Requirement | Result |
|---|---|
| IaC research + scripts | Terraform (`infra/`), azurerm 4.81, TF ≥ 1.11 (ephemeral/write-only DB password) |
| Scripts for all resources | 24 resources: RG, Log Analytics, App Insights, Storage (keys disabled, `app-package`, `pet-documents`, static website), Key Vault (RBAC), PostgreSQL Flexible B1ms v16 + DB + firewall, Functions Flex Consumption (Node 22), 6 role assignments, GitHub OIDC UAMI + federated credential |
| Tested with boilerplate | Deployed; `verify.sh` in the OIDC pipeline: frontend HTTP 200, `/api/health` 200 `{"keyVaultSecretResolved":true,"database":true,"blobStorage":true}`, CORS = frontend origin only |
| Repo with boilerplate | Public repo above; CI (gitleaks, terraform fmt/validate, tests, build) green |
| **Deviation** | SWA config kept (`frontend_hosting = "swa"`), but the subscription's allowed-regions policy (deny) excludes every SWA region → deployed with `frontend_hosting = "blob"` (Storage static website). No policy exemption. Not SWA compliance. |
| Region notes | App resources `westus`; PostgreSQL `northcentralus` (B1ms `SkuNotAvailable` in westus) |

## Cloud Security Lab
| Part | Result | Evidence (in `security/evidence/`, gitignored) |
|---|---|---|
| A | Full-history gitleaks: no findings (before + fresh clone of main, 12 commits). Manual review: none in Git. Found & fixed in Azure config: provider-injected key-based `AzureWebJobsStorage` (key unusable; shared-key auth disabled) | `gitleaks-before.json`, `gitleaks-after-main.json` |
| B | Key Vault RBAC; secret `db-admin-password`; app = Secrets User (system MI), admin = Secrets Officer; Key Vault reference Resolved | `keyvault.txt`, `rbac.txt`, `function-app.txt` |
| C | No real exposure. Controlled rotation demo: old password rejected (HTTP 503, App Insights 9× `28P01`), new works (HTTP 200). Temporary /32 firewall rule removed. No Terraform drift | `rotation-demo.txt`, `appinsights-rotation.txt`, `postgres.txt` |
| D | OIDC success on main (run 44682632588); negative test from `test-oidc` failed with AADSTS700213 (run 44693891488). Subject uses GitHub's immutable-ID format | `oidc*.txt`, `runs.txt` |
| Report | `security/Cloud-Security-Lab-Report-Molys-Log.pdf` (5 pages, both answers) | — |

Missing: Azure Portal / GitHub UI **screenshots** (report uses verbatim logs + public run URLs). Add manually if the professor requires images.

## Azure cleanup (2026-11-19/20)
Deleted (authorized): `rg-zavashop-luis` (16 resources), its AKS-managed `MC_` group (9), `rg-aks-tarea-luis-1027` (Foundry + ACR). Savings ≈ USD 30/month idle (LB, 2 public IPs, 2 ACR).
Kept (ownership uncertain / Azure-managed, ≈ $0): `cloud-computing-class-rg`, `cloud-class-rg` (empty), `DefaultResourceGroup-WUS`, `DefaultResourceGroup-CQ` (workspaces), `NetworkWatcherRG`.
Note: Defender for Key Vault (subscription plan, ~USD 0.25/vault/month) is on — user decision.

## Cost (USD/month, retail)
PostgreSQL B1ms northcentralus ≈ 12.4 + 32 GB storage ≈ 3.7; everything else < 1. **≈ 17/month.** Stop PostgreSQL when idle: `az postgres flexible-server stop -g rg-molyslog -n psql-molyslog-55kho`.

## Lessons recorded
- azurerm Flex Consumption injects a key-based `AzureWebJobsStorage`; override to `""` when keys are disabled.
- Ephemeral write-only passwords + a partially failed apply can desync Key Vault and server → bump `db_password_version`.
- Key Vault references are cached across restarts; a config change forces re-resolution.
- `az functionapp show --query defaultHostName` is null for Flex apps → use `properties.defaultHostName`.
- New GitHub repos send OIDC `sub` with immutable IDs (`owner@id/repo@id`).

## Next actions
1. Review/submit the PDF (add screenshots if required).
2. Optionally delete branch `test-oidc` after grading; stop PostgreSQL between sessions.
3. Do not `terraform destroy` without approval.
