# webapp/

Phase 5 で構築する外部公開用フルスタックアプリ。

## 構造

```
webapp/
├── api/      # FastAPI (Python). Postgres operational store を読む
└── front/    # Next.js 16 (TypeScript). API を叩いて UI 提供
```

## 役割と Streamlit との違い

| | Streamlit (`dashboard/`) | Next.js (`webapp/`) |
|--|--|--|
| 対象 | 内部・分析者 | 外部・一般ユーザー |
| データソース | DuckDB gold | Postgres operational mart |
| 目的 | 探索分析 | 操作可能な UI、長期運用 |
| 認証 | なし or 簡易 | 本格運用 |

## ライフサイクル

1. dbt gold layer 完成 (Phase 4)
2. Multiwoven で gold → Postgres mart に reverse-ETL (Phase 5)
3. FastAPI で REST/GraphQL 公開 (Phase 5)
4. Next.js で UI 構築 (Phase 5)
5. Self-host on VPS (Phase 6)
