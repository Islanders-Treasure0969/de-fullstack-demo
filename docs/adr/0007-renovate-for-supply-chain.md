# 7. Renovate を中心とした supply-chain セキュリティ

- Status: Accepted
- Date: 2026-05-09

## Context

Next.js は 2025 年だけで CVE-2025-29927 (middleware 認可バイパス) など重大脆弱性を複数経験。多言語スタック (Python / Go / Rust / TypeScript / Terraform / Docker / GitHub Actions) を 1 つのリポジトリで扱うため、依存更新の遅延が許容されない。

## Decision

- **Renovate** を一次の依存更新ボットとして採用 (Dependabot は GitHub 純正のセキュリティアラートのみ補助)
- 設定方針:
  - patch / minor: CI 通過後 **auto-merge**
  - vulnerability alerts: severity 不問で `minimumReleaseAge: 0` で**即時 PR + auto-merge**
  - major: `needs-review` ラベル付与で手動レビュー強制
  - Next.js / React は schedule 無視で 24/7 反応
  - dev dependencies はグルーピングで PR 数を抑制
- 並行して **CodeQL / Trivy / gitleaks / OpenSSF Scorecard** を CI で常時実行
- 6 時間ごとに critical Dependabot alert を Issue 化する custom workflow

## Consequences

- Next.js の zero-day も人間レビュー無しで数十分内に main に反映される
- 重大アラートを見落とすことが構造的に難しくなる
- PR 数は increase するが、グルーピングと auto-merge で実質的な負荷は低い
