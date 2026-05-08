# Architecture Overview

## Domains

- **infra**: OpenTofu / Terragrunt / Ansible — what the cloud looks like
- **pipeline**: ingestion / transform / dashboard — how data moves
- **workflow**: Temporal — how long-running processes are coordinated

## Tech stack (確定 2026-05-09)

| Layer | Technology | Notes |
|-------|-----------|-------|
| IaC (resources) | OpenTofu 1.8 + Terragrunt 1.0 | Lifecycle-layered |
| IaC (config / deploy) | Ansible | Phase 6 onwards |
| Local runtime | Docker Compose v2 | |
| AWS emulation | LocalStack (Hobby) | |
| Object store | Garage v1 | Replaces dead MinIO |
| Iceberg catalog | Lakekeeper v0.7 | Apache 2.0, Rust |
| Streaming | Apache Kafka 4.x (KRaft) + Apicurio + Provectus Kafka UI | |
| DWH | DuckDB v1.5 + iceberg extension | |
| Transform | dbt-core 1.10 → dbt Fusion (Phase 4) | dbt-duckdb adapter |
| Data quality | Soda Core + dbt tests | Replaces Great Expectations |
| Orchestration | Temporal + Go SDK | |
| Reverse ETL | Multiwoven | docker pull only (AGPL) |
| Operational DB | Postgres 17 | |
| API | FastAPI | |
| Frontend | Next.js 16 | |
| Internal BI | Streamlit | |
| Self-host | Ansible + Caddy | Phase 6 |
| Languages | Python 3.12 / Go 1.22 / Rust 1.78 / TypeScript | |

## Data flow

See [README.md](../../README.md#architecture-target) for the diagram.

## Non-goals

- Multi-region resilience (single region, single node)
- Production-grade SLOs
- Real billing / payments

This is a **learning playground**, not a production system. Production-grade decisions (replicated state, HA, SOC2 controls) are explicitly out of scope.
