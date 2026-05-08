# Runbooks

各障害シナリオへの対処手順。Phase 1+ で実際に運用しながら埋めていく。

## 想定する Runbook (将来の追加対象)

- `garage-bucket-recovery.md` — Garage ノード/データ復旧
- `lakekeeper-restart.md` — Lakekeeper の再起動と catalog 整合性確認
- `kafka-rebalance.md` — KRaft クラスタの controller 切替
- `dbt-fusion-rollback.md` — Fusion 失敗時に dbt-core に戻す
- `temporal-workflow-resume.md` — failed workflow の retry / signal
- `vpn-vpn-rotate.md` — Phase 6 VPS 上の TLS 証明書ローテーション
