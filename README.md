# de-fullstack-demo

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI](https://github.com/Islanders-Treasure0969/de-fullstack-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/Islanders-Treasure0969/de-fullstack-demo/actions/workflows/ci.yml)
[![CodeQL](https://github.com/Islanders-Treasure0969/de-fullstack-demo/actions/workflows/codeql.yml/badge.svg)](https://github.com/Islanders-Treasure0969/de-fullstack-demo/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Islanders-Treasure0969/de-fullstack-demo/badge)](https://scorecard.dev/viewer/?uri=github.com/Islanders-Treasure0969/de-fullstack-demo)

データエンジニアリングのフルスタックを実践的に学ぶための、GitHub OSS 活動分析プラットフォーム。

## What is this?

GitHub の OSS 活動 (commit / PR / issue / star) を継続的に集めて分析・可視化するエンドツーエンドのデータプラットフォーム。データエンジニアリングの全レイヤー (ingestion / storage / transform / orchestration / serving / reverse ETL / web app) を**最新のスタック**で実装する。

## Architecture (target)

```
[GitHub API / Webhooks]
        │
        ▼
[Go ingestor (bulk/batch) + Webhook receiver (streaming)]
        │
        ▼
[Garage S3 (Bronze / Parquet)] ──> [Kafka 4.x KRaft] ──> [Iceberg sink]
        │                                                   │
        └──────────────┬────────────────────────────────────┘
                       ▼
              [Iceberg + Lakekeeper REST catalog]
                       │
                       ▼
              [DuckDB read-iceberg]
                       │
                       ▼
              [dbt Fusion: bronze → silver → gold]
                       │
                       ├──> [Streamlit dashboard]
                       │
                       └──> [Reverse ETL (Multiwoven)]
                                    │
                                    ▼
                            [Postgres operational store]
                                    │
                            [FastAPI] ──> [Next.js web app]

Cross-cutting:
  - Orchestration: Temporal (Go SDK)
  - Heavy batch:   Rust (Polars / DataFusion)
  - IaC:           OpenTofu + Terragrunt (lifecycle-layered)
  - Self-host:     Ansible + Caddy (Phase 6)
  - Security:      Renovate + CodeQL + Trivy + Scorecard + Soda Core
```

## Phases

| Phase | Goal | Status |
|-------|------|--------|
| **Phase 0** | Security baseline (Renovate / CodeQL / Trivy / Scorecard / branch protection) | 🚧 In progress |
| **Phase 1** | Minimal E2E: Python ingestor → Garage → DuckDB → dbt → Streamlit | ⏳ Planned |
| **Phase 2** | Iceberg migration (Garage + Lakekeeper) + DuckDB Iceberg extension | ⏳ Planned |
| **Phase 3** | 3 ingestion modes: bulk / daily batch (Temporal+Go) / streaming (Kafka+Webhook) | ⏳ Planned |
| **Phase 4** | dbt Fusion migration + Python models (embeddings, anomaly detection) + Soda Core | ⏳ Planned |
| **Phase 5** | Reverse ETL (Multiwoven) + Postgres mart + FastAPI + Next.js 16 | ⏳ Planned |
| **Phase 6** | Self-host on VPS via Ansible + Caddy + observability | ⏳ Planned |

## Tech Stack

See [docs/architecture/overview.md](docs/architecture/overview.md) for the full stack and rationale. Decisions are recorded as ADRs in [docs/adr/](docs/adr/).

## Quickstart (Phase 0)

```bash
# 1. Clone
git clone https://github.com/Islanders-Treasure0969/de-fullstack-demo.git
cd de-fullstack-demo

# 2. Copy env template
cp .env.example .env

# 3. Bring up the platform stack
cd docker
docker compose up -d

# 4. Verify all services are healthy
docker compose ps
```

Recommended local toolchain:
- Docker Compose v2.20+
- OpenTofu 1.8+ ([install](https://opentofu.org/docs/intro/install/))
- Terragrunt 1.0+ ([install](https://terragrunt.gruntwork.io/docs/getting-started/install/))
- Python 3.12+, Go 1.22+, Rust 1.78+, Node.js 20+

## Repository structure

```
.
├── .github/             # Renovate config + 8 security workflows
├── infra/               # OpenTofu + Terragrunt (lifecycle-layered)
├── transform/           # dbt project (dbt-core → Fusion in Phase 4)
├── ingestion/           # Go (Temporal worker) + Rust (heavy batch)
├── orchestration/       # Temporal workflows
├── dashboard/           # Streamlit
├── webapp/              # FastAPI + Next.js 16
├── reverse-etl/         # Multiwoven configs
├── ansible/             # Self-host playbooks (Phase 6)
├── docker/              # docker-compose for local platform
├── docs/                # ADRs, architecture, runbooks, case studies
└── scripts/             # bootstrap, helpers
```

## Security

- See [SECURITY.md](SECURITY.md) for vulnerability reporting.
- Renovate auto-merges patch/minor + critical security updates.
- CodeQL / Trivy / gitleaks / Scorecard run on every PR and on schedule.

## License

[Apache License 2.0](LICENSE) — chosen to match the data engineering ecosystem (Iceberg / Spark / Kafka / Airflow are all Apache 2.0).

## Acknowledgments

This project is a learning playground designed to dogfood the [data-engineering-plugin](https://github.com/Islanders-Treasure0969/ai-data-engineering-project) for Claude Code.
