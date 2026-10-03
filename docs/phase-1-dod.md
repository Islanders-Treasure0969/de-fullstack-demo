# Phase 1 — Definition of Done

Phase 1 が「完了」と言える条件を明文化する。各 step は **作業者** 列で誰がやるかを明示。

## チェックリスト

| # | 条件 | 検証方法 | 作業者 |
|---|------|---------|------|
| 1 | コードが main にマージ済み | `git log --oneline origin/main \| grep "Phase 1.1"` | 🤖 完了済み (#15) |
| 2 | smoke-test が緑 (オフライン) | `make smoke-offline` | 🤖 自動 / 👤 手動でも可 |
| 3 | docker compose スタックが起動できる | `make compose-up && make compose-ps` | 👤 (Docker daemon が必要) |
| 4 | smoke-test が緑 (compose up 状態) | `make smoke` | 👤 |
| 5 | GitHub PAT を取得 | <https://github.com/settings/tokens?type=beta> | 👤 (2FA 必要) |
| 6 | `.env` に `GITHUB_TOKEN` を設定 | `grep -E '^GITHUB_TOKEN=.+' .env` | 👤 (secret) |
| 7 | `.env` にターゲット repo を設定 | `grep -E '^GITHUB_TARGET_REPOS=.+' .env` | 👤 (個人の選択) |
| 8 | Bronze バケット作成成功 | `make ingest-bootstrap` | 👤 |
| 9 | Bronze に parquet が書かれる | `make ingest` | 👤 |
| 10 | dbt build が緑 (silver/gold 全モデル + tests) | `make dbt-build` | 👤 |
| 11 | Streamlit dashboard が gold を読んで描画 | `make dashboard` → http://localhost:8501 | 👤 (ブラウザ) |

## 凡例

- 🤖 = アシスタント (Claude) が代行できるタスク
- 👤 = ユーザーしか実行できないタスク (secret / ローカル環境 / 認証 / ブラウザ)

## なぜユーザーが必須か

| タスク | 代行不可の理由 |
|-------|--------------|
| PAT 取得 | GitHub の 2FA は人間の認証が必須 |
| `.env` への secret 書込 | secret は git に乗せないのが大原則 |
| ターゲット repo 選択 | 学習者の興味と分析意図に依存 |
| Docker daemon 起動 | アシスタントの sandbox では Docker が動かない |
| ブラウザでの dashboard 確認 | 視覚的な動作確認は人間の目が必要 |

## Phase 1 完了の宣言条件

**チェックリスト 1-11 すべて緑** になった時点で `docs/case-studies/phase-1-completion.md` を書いて、Phase 2 に進む。

完了を示す軽いコマンド：

```bash
# 1〜2 はアシスタントが既にクリア
make smoke-offline                            # 2 を再確認
make compose-up && make smoke                 # 3, 4
test -n "$(grep ^GITHUB_TOKEN=... .env)" \
  && test -n "$(grep ^GITHUB_TARGET_REPOS=... .env)" && echo "5-7 OK"
make ingest-bootstrap && make ingest          # 8, 9
make dbt-build                                # 10
make dashboard                                # 11 (ブラウザで確認)
```

## トラブルシュート

[`docs/getting-started.md`](getting-started.md) の Troubleshooting セクション参照。
