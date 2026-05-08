# ingestion/go/

Go ベースの GitHub ingestor + Webhook receiver。

## ビルド (Phase 3)

```bash
cd ingestion/go
go mod tidy
go build -o bin/ingestor ./cmd/ingestor
```

## 構造

```
go/
├── cmd/
│   └── ingestor/         # エントリポイント
└── internal/
    └── github/           # GitHub API クライアント、レート制限制御
```
