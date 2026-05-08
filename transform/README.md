# transform/

dbt project. Phase 1 では `dbt-core` で書き、Phase 4 で `dbt Fusion` に移行する。

## 構造 (Medallion)

```
models/
├── bronze/   # 生データの cast / 列名標準化のみ
├── silver/   # 結合・正規化・derived columns
└── gold/     # ビジネスメトリクス、Streamlit/Multiwoven 向け
```

## 起動

```bash
cd transform
pip install dbt-core dbt-duckdb soda-core-duckdb
cp profiles.yml.example ~/.dbt/profiles.yml  # 1回だけ
dbt deps
dbt build
```

## Phase 進化

| Phase | 内容 |
|-------|------|
| 1 | bronze/silver/gold の最小モデル (SQL のみ) |
| 2 | iceberg.* に source 切替 |
| 3 | streaming events の incremental model |
| 4 | Fusion 移行 + Python model (embedding, anomaly) |
| 5 | gold → Postgres mart の reverse-ETL 連携 |

## Tooling

- `dbt-core 1.10` → `dbt Fusion` (Phase 4)
- `dbt-duckdb` adapter
- `Soda Core` for data quality (replaces Great Expectations)
- `sqlfluff` for linting
