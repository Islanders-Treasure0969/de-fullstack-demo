# 1. 3 ドメイン構造 (infra / pipeline / workflow)

- Status: Accepted
- Date: 2026-05-09

## Context

このリポジトリはデータエンジニアリングのフルスタックを 1 プロジェクトに集約する。役割が混ざるとディレクトリの所有が曖昧になり、Renovate の auto-merge ルールや CI のパス filter も書きにくい。

## Decision

トップレベルを次の 3 ドメインに分離する：

- **infra**: クラウド/プラットフォームのプロビジョニング (OpenTofu / Terragrunt / Ansible)
- **pipeline**: データの ingest / transform / serving (ingestion, transform, dashboard)
- **workflow**: 分散ワークフロー / 長期実行ジョブ (Temporal)

## Consequences

- CODEOWNERS / CI filter が綺麗に書ける
- 自作の `data-engineering-plugin` の3ドメイン構造を**そのままドッグフーディング**できる
- 各ドメイン内は独立してリリース可能
