# orchestration/

Temporal Workflow / Activity 定義。Go SDK で実装。

## 構造

```
orchestration/
├── workflows/    # Workflow definitions (deterministic)
└── activities/   # Activity implementations (side effects OK)
```

## 想定 workflow (Phase 3 以降)

| Workflow | トリガ | 役割 |
|----------|-------|------|
| `BackfillWorkflow` | 手動 / `tctl` | 過去履歴の bulk 取得 |
| `DailyIngestWorkflow` | cron (毎日 02:00 JST) | 差分 ingest + dbt build |
| `WebhookProcessorWorkflow` | Kafka stream | リアルタイム event 処理 |
| `ReverseEtlSyncWorkflow` | cron (1時間ごと) | gold → Postgres mart upsert |

## 起動

```bash
cd orchestration
go run ./worker
```

Temporal server は docker compose で起動済みのものを使用。
