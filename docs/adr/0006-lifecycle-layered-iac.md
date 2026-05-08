# 6. インフラはライフサイクル別レイヤリング

- Status: Accepted
- Date: 2026-05-09

## Context

`infra/live/<env>/` を 1 つの `terragrunt.hcl` でフラットに管理すると、低頻度変更 (IAM 等) と高頻度変更 (アプリ deploy) が混ざり、blast radius が読めなくなる。

## Decision

`live/<env>/` 配下を**変更頻度の低い順**に番号 prefix でレイヤリング：

```
00-foundation/  ← 数ヶ月に1回
01-storage/
02-streaming/
03-warehouse/
04-mart/
05-app/         ← 週数回
```

`_bootstrap/` は state 自体を作るための例外 (手動 `tofu apply`)。

## Consequences

- `terragrunt run-all plan` の差分が層単位で読める
- 各層に `dependency` ブロックを書くことで依存順序が明示される
- prod 移行時に `dev/` の構造をそのままコピーできる
