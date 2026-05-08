# reverse-etl/

Multiwoven を用いた gold → Postgres mart の reverse-ETL 設定。

## 構成

```
reverse-etl/
└── multiwoven/   # docker-compose で起動 + sync 定義 (YAML export)
```

## Phase 5 の流れ

1. Multiwoven を docker-compose で起動 (`docker/docker-compose.reverse-etl.yml`)
2. UI で sync を作成: source = DuckDB gold / destination = Postgres mart
3. sync 定義を export して `reverse-etl/multiwoven/syncs/*.yml` に commit
4. Temporal `ReverseEtlSyncWorkflow` から Multiwoven REST API 経由で trigger

## ライセンス注意

Multiwoven 本体は **AGPL-3.0**。
このリポジトリは **docker pull のみで使用**し、ソースの fork / 同梱は行わない（AGPL の伝播を避ける）。
