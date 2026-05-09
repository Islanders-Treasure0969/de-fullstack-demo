# 8. シークレット管理は 1Password CLI (`op run --env-file`)

- Status: Accepted
- Date: 2026-05-09

## Context

このリポジトリはローカル開発で複数のシークレット (GitHub PAT、Garage RPC secret、Postgres password 等) を扱う。一般的な選択肢は：

| 方式 | 評価 |
|------|------|
| 平文 `.env` を `.gitignore` で除外 | 流出時の被害が大きい (ファイル漏洩 = 全シークレット漏洩)、各 dev が手で同期、CI と dev で値ずれが起きる |
| 環境変数を直接 export | shell 履歴に残る、複数プロジェクトで衝突 |
| AWS Secrets Manager / GCP Secret Manager | クラウド依存。学習プロジェクトには重い |
| HashiCorp Vault | 自前運用が面倒 |
| **1Password CLI (`op run --env-file=.env`)** | ✅ 採用 |

## Decision

**1Password CLI** を一次のシークレット管理に採用する。

- `.env` は **git にコミット**する。中身は `op://Personal/<item>/<field>` 参照のみ
- 実行時に `op run --env-file=.env -- <command>` がシークレットを解決して child process の env に inject
- 平文 fallback として `.env.local` (gitignored) もサポート (1Password を持たない他者向け)
- CI では将来 1Password Service Account を使う

## Consequences

### Positive
- **`.env` がリポにコミットできる** ＝ team / future-self に config が transparent に伝わる
- ファイル流出 ≠ シークレット流出 (中身は参照のみ)
- 値変更が 1Password 側で一元化される
- 1Password の audit log でアクセス追跡可能
- Service Account を使えば CI/CD でも同じパターンで動く
- shell 履歴・プロセスメモリへの平文滞在時間が最小化

### Negative
- 1Password 有償サブスクリプションが前提 (個人 plan で十分)
- `op signin` の手間が増える (TouchID 連携で実質ゼロ秒)
- macOS / Linux / Windows の CLI クロスプラットフォーム対応は 1Password 側に依存

### Mitigations
- `.env.local` fallback を Makefile が自動検出して使う → 1Password なしでも動く
- `make op-create` でアイテム作成を自動化、初期セットアップを 1 コマンドに圧縮

## Impact

| 場所 | 変更 |
|------|------|
| `.env` (新規 commit) | `op://` 参照のみのテンプレート |
| `.env.example` | fallback 用平文テンプレート (`.env.local` のひな形) |
| `.gitignore` | `.env` 除外を解除、`.env.local` は除外維持 |
| `Makefile` | `OP_RUN` 変数で `op run` を自動 wrap、`make op-create` / `make op-show` 追加 |
| `scripts/bootstrap.sh` | `op` 検出 + サインイン状態チェック + fallback 切替 |
| `scripts/op-create-item.sh` (新規) | インタラクティブにアイテム作成、シークレットは `openssl rand` で自動生成 |
| `docs/getting-started.md` | 1Password 経路をデフォルト、`.env.local` を fallback に |

## References

- [1Password Secrets Automation Workflow](https://developer.1password.com/docs/cli/secrets-config-files/)
- [`op run` reference](https://developer.1password.com/docs/cli/reference/commands/run)
- [Secret references syntax](https://developer.1password.com/docs/cli/secret-reference-syntax/)
