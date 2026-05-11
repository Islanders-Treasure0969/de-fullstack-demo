# 10. Iceberg ストレージレイヤを Lakekeeper REST catalog で運用する

- Status: Accepted
- Date: 2026-05-10

## Context

Phase 1 では Bronze を Garage S3 上の Hive-partitioned Parquet として運用していた。
DuckDB の `read_parquet(...)` で読めるが、以下が辛い：

- **スキーマ進化**: ingestor 側で型がブレると `read_parquet(union_by_name=true)` の温情に頼るしかない（Phase 1 で `license_spdx` が INTEGER ↔ VARCHAR で型ドリフトを起こした実例あり）
- **ACID 一切なし**: 同じ partition を上書きする手段がなく、incremental 更新が事実上不可能
- **ファイル単位のメタデータが欠落**: 削除/更新がトラッキングできない、time-travel もない
- **クライアント間で contract が無い**: 「このバケットの parquet を読むときの規約」が暗黙

Apache Iceberg はこれを解決するテーブルフォーマット。Phase 2 ではこの問題を構造的に潰す。

## Decision

Bronze 層から **Apache Iceberg + Lakekeeper REST catalog** に切り替える。

- **テーブルフォーマット**: Apache Iceberg v2
- **Catalog**: Lakekeeper (Apache 2.0, Rust 製、ADR-0003 で採用済みの Garage と同じ言語スタック)
- **Storage**: Garage S3 上の `iceberg-warehouse` バケット (Phase 1 の `bronze` バケットとは分離)
- **Write client**: PyIceberg 0.10+
- **Read client**:
  - dbt-duckdb (Phase 2B 以降)
  - DuckDB iceberg extension via `ATTACH ... TYPE ICEBERG`

## Architecture

```
[Python ingestor]                       (Phase 2B)
    │ PyIceberg.append()
    ▼
[Lakekeeper REST catalog] @ :8181/catalog
    │ stores table metadata in Postgres
    │ tells clients where the data lives
    ▼
[Garage S3 / iceberg-warehouse/]        ← actual data
    │ parquet files + metadata files (.avro snapshots, manifest lists)
    │
[DuckDB on host]
    │ ATTACH 'de_lab' AS lakekeeper (TYPE ICEBERG, AUTHORIZATION_TYPE 'none');
    │ SELECT ... FROM lakekeeper.<namespace>.<table>;
    ▼
dbt models → Streamlit
```

## Implementation in Phase 2A (this ADR's PR)

1. `docker-compose.yml`: split `lakekeeper` into a one-shot `lakekeeper-migrate`
   init container (runs `lakekeeper migrate`) + the long-running `lakekeeper`
   serve container (depends on `service_completed_successfully`).
2. `scripts/garage-init.sh`: also create the `iceberg-warehouse` bucket (and
   grant the existing `de-lab` key access).
3. `scripts/lakekeeper-init.sh`: idempotent server bootstrap +
   `de_lab` warehouse creation via the management REST API.
4. `scripts/iceberg-poc.py`: PyIceberg write + DuckDB iceberg ATTACH read,
   exercised by `make iceberg-poc`.

## Consequences

### Positive
- スキーマ進化が catalog 経由で trackable に (column add/rename/type change)
- ACID トランザクション（snapshot ベース）でテーブル書き換えできる
- time-travel が無料で付いてくる (`AS OF SNAPSHOT`)
- Lakekeeper UI で warehouse / table の一覧と監査ログが見える

### Negative
- Stack のレイヤがひとつ増える (Lakekeeper 自体の運用)
- DuckDB iceberg ATTACH は `AUTHORIZATION_TYPE 'none'` を渡さないと OAuth2 を要求する罠（v0.12 時点）
- `remote-signing-enabled: true` (Lakekeeper 既定) と PyIceberg の s3fs が嚙み合わず、
  「Garage does not support anonymous access」で書込み失敗する。Phase 2A では暫定で
  `remote-signing-enabled: false` にして直接 access-key 渡しに切替

### Trade-offs we are not paying right now
- **vended credentials**: Lakekeeper が STS 短命トークンを発行するモードは AWS S3 でのみ機能する。
  Garage は STS を実装しないので諦める (Phase 6 の本番 AWS 移行で再検討)
- **OpenFGA authz**: 今の dev は `authz-backend: allow-all`。本番では OpenFGA / OIDC を
  繋げる必要があるが Phase 2 では Out of scope

## Known Phase 2A blockers

| # | Issue | Workaround |
|---|-------|------------|
| 1 | Lakekeeper の S3 endpoint が docker network 名 (`http://garage:3900`) になり host 側クライアントから解決できない | warehouse の endpoint を host LAN IP (`192.168.11.51`) に書き換え。`lakekeeper-init.sh` が `ipconfig getifaddr en0` で動的検出 |
| 2 | `remote-signing-enabled: true` だと PyIceberg s3fs が anonymous request になる | warehouse を `remote-signing-enabled: false` で再作成 |
| 3 | DuckDB iceberg ATTACH が既定で OAuth2 を要求 | `AUTHORIZATION_TYPE 'none'` を渡す |
| 4 | DuckDB iceberg ATTACH が `CREATE SECRET` を読まないことがある | 古典的な `SET s3_endpoint=...` の global config を使う |

## Phase 2B (follow-up)

1. ingestor を Iceberg 書き込みに切り替え (`storage.py` を PyIceberg 化)
2. dbt bronze stg_*.sql を `read_parquet` から `lakekeeper.<ns>.<tbl>` に置換
3. Streamlit 側はそのまま (gold は変更不要)
4. `docs/case-studies/parquet-vs-iceberg.md` を書く

## References

- [Lakekeeper Docs - Getting Started](https://docs.lakekeeper.io/getting-started/)
- [Lakekeeper REST API](https://docs.lakekeeper.io/docs/0.10.x/api/catalog/)
- [PyIceberg](https://py.iceberg.apache.org/)
- [DuckDB Iceberg extension](https://duckdb.org/docs/extensions/iceberg)
