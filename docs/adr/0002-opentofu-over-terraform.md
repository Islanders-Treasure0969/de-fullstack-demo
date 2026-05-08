# 2. OpenTofu を Terraform より優先採用

- Status: Accepted
- Date: 2026-05-09

## Context

2023 年の HashiCorp ライセンス変更 (BSL) 以降、IaC 標準は Terraform と OpenTofu に二分。2026 年時点で OpenTofu は CNCF プロジェクトとして安定し、Boeing / Capital One 等の本番採用例 (採用率 12% 程度) を持つ。Terragrunt も 1.0 GA で OpenTofu / Terraform の両対応を明言している。

## Decision

新規プロジェクトで OpenTofu (>= 1.8) を採用する。Terraform への切り戻しは設定ファイルの差分が小さいため低コスト。

## Consequences

- ライセンス的に MPL 2.0 で完全 OSS
- 新機能 (provider iteration, state encryption など) を先取り可能
- GitHub Actions では `opentofu/setup-opentofu` を使用
- 既存の Terraform ナレッジは 99% そのまま流用可能
