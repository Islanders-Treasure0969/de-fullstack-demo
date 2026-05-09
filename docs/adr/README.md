# Architecture Decision Records

[MADR](https://adr.github.io/madr/) format. New decisions: copy `0000-template.md`, increment the number, and link from the index below.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](0001-three-domain-architecture.md) | 3 ドメイン構造 (infra / pipeline / workflow) | Accepted |
| [0002](0002-opentofu-over-terraform.md) | OpenTofu を Terraform より優先採用 | Accepted |
| [0003](0003-garage-over-minio.md) | MinIO ではなく Garage を採用 | Accepted |
| [0004](0004-kafka-over-redpanda.md) | Streaming は Apache Kafka 4.x (KRaft) | Accepted |
| [0005](0005-fusion-migration-strategy.md) | dbt-core で開始、Phase 4 で Fusion 移行 | Accepted |
| [0006](0006-lifecycle-layered-iac.md) | インフラはライフサイクル別レイヤリング | Accepted |
| [0007](0007-renovate-for-supply-chain.md) | Renovate を中心とした supply-chain セキュリティ | Accepted |
| [0008](0008-secrets-via-1password.md) | シークレット管理は 1Password CLI | Accepted |
| [0009](0009-coderabbit-ai-review.md) | AI コードレビューに CodeRabbit を採用 | Accepted |
