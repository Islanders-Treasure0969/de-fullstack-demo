# Getting Started — Phase 1

クローンしたばかりの状態から **Phase 1 の最小 E2E パイプラインを動かす**手順。

## 必要なもの

| Tool | Version | Install |
|------|---------|---------|
| Docker / Compose v2 | 2.20+ | [docker.com](https://docs.docker.com/get-docker/) |
| Python | 3.12+ | [python.org](https://www.python.org/downloads/) |
| GNU Make | 任意のバージョン | macOS は標準。Linux は `apt install make` |
| `gh` CLI | 任意 | [cli.github.com](https://cli.github.com/) |
| `pre-commit` | 任意 | `pip install pre-commit` |
| OpenTofu | 1.8+ (Phase 2 以降) | [opentofu.org](https://opentofu.org/docs/intro/install/) |
| Terragrunt | 1.0+ (Phase 2 以降) | [terragrunt.gruntwork.io](https://terragrunt.gruntwork.io/docs/getting-started/install/) |

## ステップ

### 1. クローン & 初期化

```bash
git clone https://github.com/Islanders-Treasure0969/de-fullstack-demo.git
cd de-fullstack-demo
make bootstrap   # .env 生成、シークレット自動入力、compose 起動
```

### 2. GitHub PAT を取得して `.env` に書く

1. <https://github.com/settings/tokens?type=beta> で Fine-grained PAT を作成
2. **Resource access**: `Public Repositories (read-only)` を選択
3. **Permissions**: 全部 No access のまま（public 限定なら read-only で十分）
4. 期限: 90 日 を推奨
5. 生成したトークンを `.env` の `GITHUB_TOKEN=` にコピー

### 3. ターゲット OSS リポを決める

`.env` の `GITHUB_TARGET_REPOS=` に**カンマ区切り**で書く。最初は 3-5 リポくらいに絞ること（API rate limit 5,000 req/h を消費する）。

おすすめの初期セット：

```env
GITHUB_TARGET_REPOS=anthropics/claude-code,dbt-labs/dbt-core,apache/iceberg,duckdb/duckdb,temporalio/temporal
```

なぜこの 5 つが題材として良いか：

| Repo | 学べること |
|------|-----------|
| `anthropics/claude-code` | AI ツールの dev velocity（最新トレンド） |
| `dbt-labs/dbt-core` | あんたの本業の本丸 |
| `apache/iceberg` | このプロジェクトで採用してる lake 形式の本家 |
| `duckdb/duckdb` | DWH エンジン本体 |
| `temporalio/temporal` | workflow ドメインの心臓部 |

全部この repo の技術スタックに直結してて、**自分の prod 採用判断にもそのまま使えるダッシュボード**になるわ。

### 4. Python ingestor をインストールして実行

```bash
make ingest-install        # venv + pip install -e ".[dev]"
make ingest-test           # ユニットテスト走るのを確認
make ingest-bootstrap      # Garage に bronze バケット作成
make ingest                # 実際に GitHub API → Bronze (parquet)
```

API rate limit 残量を確認したいなら：

```bash
curl -H "Authorization: Bearer $(grep GITHUB_TOKEN .env | cut -d= -f2)" \
  https://api.github.com/rate_limit | jq .resources.core
```

### 5. dbt build

```bash
# 初回だけ profiles.yml を ~/.dbt/ にコピー
mkdir -p ~/.dbt && cp transform/profiles.yml.example ~/.dbt/profiles.yml

make dbt-deps     # dbt_utils etc.
make dbt-build    # bronze → silver → gold + tests
```

### 6. Streamlit dashboard

```bash
pip install -r dashboard/streamlit/requirements.txt   # 1回だけ
make dashboard
```

→ <http://localhost:8501> で開く。

### 7. (オプション) すべてを 1 コマンドで

```bash
make phase1
```

`compose-up → ingest-bootstrap → ingest → dbt-deps → dbt-build → dashboard` を順番に実行する。

## トラブルシューティング

| 症状 | 原因 | 解決 |
|------|-----|------|
| `make ingest` で 401 | `GITHUB_TOKEN` 不正 / 期限切れ | PAT 再生成 |
| `make ingest` で 403 | rate limit 到達 | 1 時間待つ。または target を減らす |
| Garage 接続エラー | compose 起動済みか | `make compose-ps` で確認 |
| dbt で `httpfs` not found | DuckDB extension 未インストール | `dbt run-operation install_extensions` か手動で `INSTALL httpfs;` |
| Streamlit が空 | gold モデル未ビルド | `make dbt-build` 先に走らせる |

## 次のステップ

Phase 1 が動いたら、Phase 2 (Iceberg 移行) に進む。`docs/adr/0006-lifecycle-layered-iac.md` と `infra/README.md` を読んで OpenTofu + Terragrunt の構造を頭に入れてから着手。
