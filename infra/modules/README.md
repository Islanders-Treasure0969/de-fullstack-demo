# Local OpenTofu Modules

Reusable modules used by `live/<env>/<component>/terragrunt.hcl` via `terraform { source = "../../../modules/<name>" }`.

## Modules

| Module | Purpose | Phase |
|--------|---------|-------|
| `kafka-topic/` | Kafka topic + retention + ACL | Phase 3 |
| `postgres-role/` | Postgres role + DB + grants | Phase 5 |
| `iceberg-warehouse/` | Lakekeeper warehouse + namespaces | Phase 2 |

## Convention

Each module ships:
- `main.tf` (resources)
- `variables.tf` (inputs)
- `outputs.tf` (outputs)
- `versions.tf` (provider/version constraints)
- `README.md` (usage)
