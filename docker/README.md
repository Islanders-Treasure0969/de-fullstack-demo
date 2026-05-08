# docker/

ローカルプラットフォーム一式の docker-compose 定義。

## ファイル構成

| ファイル | 用途 | Phase |
|---------|------|-------|
| `docker-compose.yml` | コア (LocalStack, Garage, Lakekeeper, Postgres, Temporal) | Phase 0+ |
| `docker-compose.streaming.yml` | Kafka 4.x (KRaft) + Schema Registry + Kafka UI | Phase 3+ |
| `docker-compose.reverse-etl.yml` | Multiwoven | Phase 5+ |

## 起動

```bash
# Phase 0+ コア
docker compose up -d

# Phase 3+ ストリーミング追加
docker compose -f docker-compose.yml -f docker-compose.streaming.yml up -d

# Phase 5+ Reverse ETL
docker compose -f docker-compose.yml -f docker-compose.streaming.yml -f docker-compose.reverse-etl.yml up -d
```

## ボリューム

`docker/data/` は各サービスの永続ボリュームのマウント先。`.gitignore` で除外。

## ポート一覧

| サービス | ポート | 用途 |
|---------|-------|------|
| LocalStack | 4566 | AWS API |
| Garage S3 | 3900 | S3-compatible API |
| Garage Admin | 3903 | 管理 API |
| Lakekeeper | 8181 | Iceberg REST catalog |
| Postgres | 5432 | operational mart |
| Temporal | 7233 | gRPC |
| Temporal UI | 8233 | Web UI |
| Kafka | 9092 | bootstrap |
| Kafka UI | 8080 | Web UI |
| Schema Registry | 8081 | REST |
