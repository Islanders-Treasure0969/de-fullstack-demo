# Getting Started — Phase 1

クローンしたばかりの状態から **Phase 1 の最小 E2E パイプラインを動かす**手順。

## 必要なもの

| Tool | Version | Install |
|------|---------|---------|
| Docker / Compose v2 | 2.20+ | [docker.com](https://docs.docker.com/get-docker/) |
| Python | 3.12+ | [python.org](https://www.python.org/downloads/) |
| GNU Make | 任意のバージョン | macOS は標準。Linux は `apt install make` |
| **1Password CLI (`op`)** | **2.30+** (推奨) | `brew install --cask 1password-cli` |
| `gh` CLI | 任意 | [cli.github.com](https://cli.github.com/) |
| `pre-commit` | 任意 | `pip install pre-commit` |
| OpenTofu | 1.8+ (Phase 2 以降) | [opentofu.org](https://opentofu.org/docs/intro/install/) |
| Terragrunt | 1.0+ (Phase 2 以降) | [terragrunt.gruntwork.io](https://terragrunt.gruntwork.io/docs/getting-started/install/) |

> 💡 **シークレット管理は 1Password CLI が推奨**。`.env` に平文を置きたくない設計。
> 1Password を使わない場合は `.env.local` (gitignored) に直書きする fallback あり。

## ステップ

### 1. クローン & サインイン

```bash
git clone https://github.com/Islanders-Treasure0969/de-fullstack-demo.git
cd de-fullstack-demo

# 1Password CLI にサインイン（macOS なら 1Password アプリと連携）
op signin
```

### 2. GitHub PAT を取得

1. <https://github.com/settings/tokens?type=beta> で Fine-grained PAT を作成
2. **Resource access**: `Public Repositories (read-only)` を選択
3. **Permissions**: 全部 No access のまま
4. 期限: 90 日 を推奨
5. `github_pat_xxxxxx...` をクリップボードにコピー（**この画面でしか見れない**）

### 3. 1Password アイテムを作成（インタラクティブ）

```bash
make op-create
```

プロンプトに従って：
- `GITHUB_TOKEN`: 上で取得した PAT を貼る
- `GITHUB_TARGET_REPOS`: 監視対象 OSS（デフォルト 5 リポ）

その他のシークレット (`GARAGE_RPC_SECRET` 等) は **`openssl rand -hex` で自動生成**して 1Password に登録される。

確認：

```bash
op item get de-fullstack-demo --vault Personal
make op-show          # マスク済み env を表示
```

### 4. プラットフォーム起動

```bash
make bootstrap        # secret backend 検出 + pre-commit + docker compose up
make compose-ps       # サービス健全性確認
```

### 5. Phase 1 パイプラインを実行

```bash
make ingest-install   # Python ingestor を venv にインストール
make ingest-test      # ユニットテスト走るのを確認
make phase1           # ingest → dbt → dashboard を一気に
```

→ <http://localhost:8501> で Phase 1 ダッシュボードが開く。

## 1Password を使わないケース（fallback）

```bash
cp .env.example .env.local
# エディタで .env.local を開いて GITHUB_TOKEN 等を手書き
make bootstrap        # .env.local を検出して使う
make phase1
```

`.env.local` は `.gitignore` 済み。Makefile が自動で検出して `op run` の代わりに `set -a && source .env.local` するわ。

## おすすめのターゲット OSS

| Repo | 学べること |
|------|-----------|
| `anthropics/claude-code` | AI ツールの dev velocity（最新トレンド） |
| `dbt-labs/dbt-core` | あんたの本業の本丸 |
| `apache/iceberg` | このプロジェクトで採用してる lake 形式の本家 |
| `duckdb/duckdb` | DWH エンジン本体 |
| `temporalio/temporal` | workflow ドメインの心臓部 |

全部この repo の技術スタックに直結してて、**自分の prod 採用判断にもそのまま使えるダッシュボード**になる。

## API rate limit を確認したい時

```bash
op run --env-file=.env -- bash -c \
  'curl -sH "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit | jq .resources.core'
```

返事が `limit: 5000` なら成功。`limit: 60` だと PAT が効いてない。

## トラブルシューティング

| 症状 | 原因 | 解決 |
|------|-----|------|
| `op run` で `[ERROR] error reading "..."` | `op signin` してない | `op signin` |
| `op item get` で 404 | アイテム未作成 | `make op-create` |
| `make ingest` で 401 | PAT 不正 / 期限切れ | 1Password で値を更新 |
| `make ingest` で 403 | rate limit 到達 | 1 時間待つ。または target を減らす |
| Garage 接続エラー | compose 起動済みか | `make compose-ps` で確認 |
| dbt で `httpfs` not found | DuckDB extension 未インストール | `INSTALL httpfs;` を手動で |
| Streamlit が空 | gold モデル未ビルド | `make dbt-build` 先に走らせる |

## 次のステップ

Phase 1 が動いたら、Phase 2 (Iceberg 移行) に進む。`docs/adr/0006-lifecycle-layered-iac.md` と `infra/README.md` を読んで OpenTofu + Terragrunt の構造を頭に入れてから着手。
