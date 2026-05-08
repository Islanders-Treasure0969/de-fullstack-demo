# webapp/front/

Next.js 16 (App Router + Turbopack) で構築する外部向け Web フロント。Phase 5 で実装。

## 初期化 (Phase 5 着手時)

```bash
cd webapp
npx create-next-app@latest front \
  --typescript \
  --tailwind \
  --eslint \
  --app \
  --turbopack \
  --import-alias "@/*"
```

## セキュリティ

- Renovate が `next` / `react` / `react-dom` を **24/7 即時 PR**で更新する設定 (`.github/renovate.json`)
- CodeQL が JS/TS をスキャン
- 重大脆弱性は 6 時間以内に Issue 化される

Phase 0 の現時点では `package.json` も置かない（`create-next-app` 結果を Phase 5 で commit する）。
