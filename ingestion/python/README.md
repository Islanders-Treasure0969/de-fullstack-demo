# ingestion/python/

Phase 1 用の最小 Python ingestor。`httpx` で GitHub API を叩き、Bronze (Garage S3) に Parquet で書く。

## 起動

```bash
cd ingestion/python

# uv 推奨 (高速)
uv venv
source .venv/bin/activate
uv pip install -e ".[dev]"

# pip でもOK
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"

# 動作確認
de-lab-ingestor --help
de-lab-ingestor bootstrap         # bronze バケット作成
de-lab-ingestor ingest            # 全 target repo 取得
de-lab-ingestor ingest --repo dbt-labs/dbt-core
```

## 設定

`.env` (リポルートの `.env`) を読む。**必須**:

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | PAT with `public_repo` read scope |
| `GITHUB_TARGET_REPOS` | `owner/repo` をカンマ区切り |
| `GARAGE_S3_*` | Garage S3 接続情報 |

`.env.example` に全変数の雛形あり。

## アーキテクチャ

```
[GitHub REST API]
       │ httpx + tenacity (retry, rate-limit aware)
       ▼
[Pydantic models] ── 型安全な層
       │
       ▼
[pyarrow Parquet]
       │
       ▼
[boto3 → Garage S3]
   bronze/<owner>/<repo>/<event_type>/year=YYYY/month=MM/day=DD/<uuid>.parquet
```

## 何を取得するか (Phase 1)

| Endpoint | 出力 | 頻度 |
|----------|-----|------|
| `GET /repos/{owner}/{repo}` | repo metadata (stars, forks, etc.) | snapshot |
| `GET /repos/{owner}/{repo}/issues?state=all&since=...` | issues + PRs | incremental |
| `GET /repos/{owner}/{repo}/commits?since=...` | commits | incremental |

Phase 3 で Webhook receiver と Temporal worker に置き換える。

## テスト

```bash
pytest                # ユニットテスト (respx で HTTP モック)
ruff check src tests  # lint
ruff format src tests # format
mypy                  # 型チェック
```
