# ingestion/rust/

Rust ベースの heavy-batch / Parquet 変換ツール群。Polars + DataFusion を使う。

## ビルド (Phase 3+)

```bash
cd ingestion/rust
cargo build --release
```

## 想定ユースケース

- 過去5年分の GitHub event 履歴を一括ダウンロードして Parquet 化
- DuckDB / Iceberg に直接書き込む
- 大規模再集計バッチの hot-path
