# 3. オブジェクトストアは MinIO ではなく Garage

- Status: Accepted
- Date: 2026-05-09

## Context

S3 互換オブジェクトストアの定番 MinIO は 2026/2 にリポジトリが maintenance mode に入り、`THIS REPOSITORY IS NO LONGER MAINTAINED` を宣言。Web Console 機能も削除され、Enterprise 版誘導のフェーズに入った。新規プロジェクトで採用する選択肢ではない。

## Decision

[Garage](https://garagehq.deuxfleurs.fr/) (Rust, AGPL-3.0) を採用する。

代替候補との比較：

| 候補 | 評価 | 理由 |
|------|------|------|
| MinIO | × | 死んでいる |
| **Garage** | ★★★ | 軽量、Rust 製でこのプロジェクトの言語学習に整合 |
| SeaweedFS | ★★☆ | 機能豊富だが本プロジェクトには過剰 |
| LocalStack S3 統合 | ★★☆ | Iceberg 用途と分離した方が責務が明確 |

## Consequences

- AGPL-3.0 だが**サービスとして利用するだけ**ならコピーレフト伝播はない
- バイナリ単体で動くので docker compose の構成がシンプル
- Rust エコシステムへの接点が増える (Polars / DataFusion と整合)
