# 4. Streaming は Apache Kafka 4.x (KRaft mode)

- Status: Accepted
- Date: 2026-05-09

## Context

ローカル開発のストリーミング基盤として Redpanda と Apache Kafka を比較。Redpanda は単一バイナリで軽量 (BSL ライセンス) という強みがあったが、Kafka 4.0 で ZooKeeper が完全廃止され KRaft モード単独で動作するようになり、シングルノード構成の負荷差が縮小した。

## Decision

Apache Kafka 4.x (KRaft mode, `bitnami/kafka:4.0`) を採用。

## Consequences

- ライセンスは Apache 2.0 (Redpanda の BSL より自由)
- 業界標準の Kafka エコシステム (Connect / Streams / Schema Registry) を学べる
- Apicurio Schema Registry (Apache 2.0) と Provectus Kafka UI を併用
- 求人で問われる頻度が高く、学習価値が直接的
