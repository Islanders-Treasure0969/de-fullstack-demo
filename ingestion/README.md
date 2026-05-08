# ingestion/

GitHub API / Webhook からデータを取得して Bronze ストレージに書き出す層。

## 構成

```
ingestion/
├── go/      # Phase 3: 並列 ingestor + Temporal worker (Go SDK)
└── rust/    # Phase 3+: heavy batch (大量履歴の Parquet 化、Polars 活用)
```

## 役割分担

| 言語 | 担当 | 理由 |
|------|------|------|
| **Go** | API 並列取得、Webhook receiver、Temporal worker | I/O 並列・goroutine・Temporal SDK の成熟度 |
| **Rust** | 過去5年バックフィルなど CPU バウンド | Polars / DataFusion の性能、メモリ安全 |

Phase 1-2 は Python で簡易実装し、Phase 3 で Go + Rust に置き換える。
