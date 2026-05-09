# 9. AI コードレビューに CodeRabbit を採用

- Status: Accepted
- Date: 2026-05-10

## Context

シングルメンテナのリポジトリでは PR の人間レビュアーが事実上不在になり、自分で書いたコードのレビューを自分で完結させざるを得ない。すでに supply-chain 系（Renovate / CodeQL / Trivy / gitleaks / Scorecard）は走っているが、これらは「既知の脆弱性パターン」と「lint」しか拾わない。**設計の質**や**プロジェクト規約への適合**を見るレイヤーが不足している。

候補：

| ツール | 評価 |
|--------|------|
| **CodeRabbit** | OSS 無料 tier、yaml 設定、path-instructions、日本語レビュー対応、Renovate/Dependabot bot ignore | ✅ 採用 |
| GitHub Copilot for PR | GitHub Pro+ 必要、設定柔軟性に劣る |
| Greptile | ローカル context は強いが Free tier が限定的 |
| Cody (Sourcegraph) | エンタープライズ向け、軽量レビュー用途には過剰 |
| 自前 Claude Code agent | 既存の subagent エコシステム流用は可能だがメンテ負荷あり |

## Decision

**CodeRabbit Pro Free Tier (OSS リポ向け)** を採用し、設定を `.coderabbit.yaml` で管理する。

主な設定方針：

- **`profile: assertive`** — bug + security に加えて style / naming / docs / test coverage にも踏み込む
- **`language: ja-JP`** — レビューと summary を日本語で受け取る
- **`path_instructions`** — ディレクトリ別の規約 (Python は mypy strict、dbt は medallion 規約、infra は OpenTofu 限定 等) を明文化し、CodeRabbit に "プロジェクト規約として" 認識させる
- **`ignore_usernames: [renovate[bot], dependabot[bot]]`** — bot PR は既存の Renovate auto-merge 経路に任せて、AI レビューは人間 (＝自分) の PR にだけ走らせる
- **`request_changes_workflow: false`** — auto-merge を阻害しない。required status checks は既存の CI / CodeQL / Trivy / gitleaks で十分
- **`finishing_touches.unit_tests: false`** — テストは人間が設計する。AI に勝手に書かせない

## Consequences

### Positive
- **設計レベルのレビュー**が PR ごとに自動で入る
- 規約 (medallion / OpenTofu / 1Password) の逸脱が即座に検出される
- 日本語で readable なので、再開時のコンテキスト復帰が早い
- Renovate の noise を受けないので signal/noise が高い

### Negative
- 第三者 SaaS が PR diff を読む（OSS リポなら問題なし、private 化したら再評価）
- 誤検知の可能性（特に `assertive` profile）→ `.coderabbit.yaml` の path_instructions で随時調整

### Neutral
- 設定は `@coderabbitai configuration` で PR 上から取得して `.coderabbit.yaml` に commit する運用にする（GitOps）

## References

- [CodeRabbit Configuration Reference](https://docs.coderabbit.ai/reference/configuration)
- [Schema: schema.v2.json](https://coderabbit.ai/integrations/schema.v2.json)
- [`.coderabbit.yaml`](../../.coderabbit.yaml)
