# infra/

OpenTofu + Terragrunt で**ライフサイクル別**にレイヤリングしたインフラ構成。

## ディレクトリ構造

```
infra/
├── modules/                # 再利用可能なローカルモジュール
│   ├── kafka-topic/        # Kafka topic + ACL
│   ├── postgres-role/      # Postgres role + DB + grants
│   └── iceberg-warehouse/  # Lakekeeper warehouse
├── _envcommon/             # env 横断の component 設定
└── live/                   # 環境別の terragrunt 単位
    ├── _bootstrap/         # state bucket 等の最初の1回 (手動 apply)
    ├── dev/                # ローカル LocalStack/Garage/Kafka を相手にする
    │   ├── env.hcl
    │   ├── 00-foundation/  # 最も低頻度: identity, base config
    │   ├── 01-storage/     # 中頻度: buckets
    │   ├── 02-streaming/   # 中頻度: kafka topics
    │   ├── 03-warehouse/   # 中頻度: iceberg warehouse
    │   ├── 04-mart/        # 中頻度: postgres roles/schemas
    │   └── 05-app/         # 高頻度: github branch protection, deploy
    └── prod/               # 将来 AWS 本番に切替する時に同じ構造を流用
```

## ライフサイクル設計の原則

番号 prefix が**変更頻度**を表す。番号が小さいほど安定（基盤）、大きいほど頻繁（アプリ寄り）。

| Layer | 変更頻度 | 影響範囲 |
|-------|--------|--------|
| `_bootstrap` | 1回のみ | state 自体 |
| `00-foundation` | 数ヶ月に1回 | 全レイヤー |
| `01-storage` 〜 `04-mart` | 月数回 | 当該コンポーネント |
| `05-app` | 週数回 | アプリと連動 |

## 使い方 (Phase 1 以降)

```bash
# 1) state bucket bootstrap (最初の1回だけ)
cd infra/live/_bootstrap
tofu init && tofu apply

# 2) dev env を順番に apply
cd ../dev
terragrunt run-all plan
terragrunt run-all apply
```

## ツールチェーン

- OpenTofu 1.8+ ([install](https://opentofu.org/docs/intro/install/))
- Terragrunt 1.0+ ([install](https://terragrunt.gruntwork.io/docs/getting-started/install/))

## Phase 0 status

このディレクトリは**スケルトン**。実際のリソース定義は Phase 1 以降で順次追加する。
