# 5. dbt-core で開始、Phase 4 で Fusion 移行

- Status: Accepted
- Date: 2026-05-09

## Context

dbt Fusion は Rust 製の次世代エンジンで、2026/4 時点で DuckDB adapter が public beta。本格採用したいが、まだ GA 前で fragility が残る。

## Decision

- Phase 1-3: `dbt-core 1.10` + `dbt-duckdb` で安定的に進める
- Phase 4: Fusion へ移行し、移行プロセス自体を `docs/case-studies/` に記録
- Fusion がコケた場合は dbt-core にフォールバック可能な状態を保つ

## Consequences

- 自作 `migrating-dbt-core-to-fusion` スキルを実プロジェクトでドッグフーディング可能
- 移行体験そのものがポートフォリオ価値になる
- dbt SQL model + Python model (Polars 返り値) を Phase 4 で同時投入
