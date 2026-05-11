# Parquet vs Apache Iceberg — Bronze 層を切替えてみた観測録

> de-fullstack-demo の Phase 1 (Hive-partitioned parquet on Garage S3) →
> Phase 2B (Apache Iceberg via Lakekeeper REST catalog) 切替の実測ベース比較。
>
> 結論を先に言うと、**個人プロジェクトでも Iceberg 化のコストは半日**、
> **ROI は schema 進化 / time travel / 後段の catalog 互換性で取り戻す**。

## TL;DR

| 観点 | parquet (Phase 1) | Iceberg (Phase 2B) | 勝者 |
|------|------------------|--------------------|------|
| 書込み speed | 直書き、ファイル分割が hash partition | catalog API 1 往復 + snapshot 作成 | parquet 微差 |
| 読込み speed | DuckDB `read_parquet` direct | DuckDB ATTACH 経由メタデータ解決 | dbt 全体だと誤差 |
| schema 進化 | 手動。型 drift で dbt build がコケる | catalog で版管理 | **Iceberg** |
| ACID / snapshot | ❌ | ✅ snapshot 単位 | **Iceberg** |
| time travel | ❌ | ✅ snapshot id / timestamp | **Iceberg** |
| 削除 / 更新 | rewrite 必須 | MERGE / DELETE | **Iceberg** |
| 運用観測性 | `aws s3 ls` で直感的 | metadata.json / manifest を読む必要 | parquet |
| 学習コスト | ほぼゼロ | 高い（snapshot / field-id / partition spec） | parquet |
| Cloud 移行性 | Glue Crawler 経由 | Glue Catalog ネイティブ | **Iceberg** |

→ **チーム / 中長期運用なら Iceberg**、
　**5 repo の個人 PoC で完結するなら parquet で十分**。

## 1. 切替の動機

Phase 1 で Bronze を Hive-partitioned parquet として運用していて、
以下の3点が苦しくなってきた:

1. **schema drift**: GitHub API が optional field を返したり返さなかったりすると、
   parquet ファイル間で nullability / 型がズレ、dbt の binder が落ちる
2. **再投入の不安**: 同じ日に 2 回 ingest すると重複が出る or 上書きが煩雑
3. **後段への接続**: Athena / Trino / Spark などに接続したくなったとき、
   Glue Crawler を別途回さないとスキーマが取れない

Iceberg は **catalog がスキーマ進化と snapshot を管理**し、**Athena / Trino / Spark が
catalog API でネイティブに参照できる**ので、上記の3点を一気に解決できる。

## 2. 実装したアーキ

### Before (Phase 1, parquet)

```
GitHub API
    │
    ▼
[ingestion/python]            ←  Pydantic v2 / aiohttp
    │
    ▼
BronzeWriter (write_parquet)
    │
    ▼
s3://bronze/{event_type}/dt=YYYY-MM-DD/repo=<owner>__<repo>/part-*.parquet
    │
    ▼
dbt: from read_parquet('s3://bronze/...') → silver → gold (DuckDB local)
    │
    ▼
Streamlit (DuckDB file 直読み)
```

### After (Phase 2B, Iceberg)

```
GitHub API
    │
    ▼
[ingestion/python]
    │
    ▼
IcebergBronzeWriter (PyIceberg)
    │
    ▼
Lakekeeper REST catalog ──→ s3://iceberg-warehouse/warehouse/<table>/...
    │
    ▼
dbt: ATTACH lakekeeper / from lakekeeper.bronze.<table> → silver → gold (DuckDB local)
    │
    ▼
Streamlit (DuckDB file 直読み — 変更なし)
```

**silver / gold は変更なし**。Iceberg はあくまで bronze 層の取り回しを置換した。

## 3. 実装コスト

### コード変更量

| ファイル | 種別 | 行数（目安） |
|---------|------|-------------|
| `ingestion/python/src/de_lab_ingestor/iceberg_storage.py` | 新規 | +220 |
| `ingestion/python/src/de_lab_ingestor/cli.py` | 修正 | +40 |
| `ingestion/python/src/de_lab_ingestor/config.py` | 修正 | +10 |
| `ingestion/python/pyproject.toml` | 修正 | +1 |
| `transform/dbt_project.yml` | 修正 | +20 |
| `transform/models/bronze/stg_*.sql` (×3) | 書き換え | ±15 |
| `scripts/lakekeeper-init.sh` | 強化 | +60 |

実装者 (= 私) の体感: **設計 30 分 + 実装 2 時間 + 罠デバッグ 2 時間 = 半日**。
ADR-0010 と Phase 2A の事前 PoC があったから半日で済んだ。
ゼロから始めると 1〜2 日かかると思う。

### 既存 parquet writer は残した

`--backend=iceberg|parquet` の CLI flag で切替可能。
Phase 2C で旧 parquet writer を削除する想定。
AB 比較できる期間を 1 phase 分残すのは保険として有効。

## 4. 数値で観察した差

### bronze の行数（同一 ingest, 5 repos）

```
bronze.stg_repo_metadata      5
bronze.stg_issue_or_pr     8459
bronze.stg_commit           328
```

parquet 経路と Iceberg 経路でカウントは完全一致。
gold 指標も一致:

```
anthropics/claude-code : 122,405 stars / commits28d=11 / prs28d=17 / issues28d=4417
```

→ **データ的に等価**。これが切替の前提。

### 書込み時間（観測ベース、ばらつき大）

GitHub API rate limit が支配的なので、I/O 自体は微差:
- parquet: 5 repos の ingest 全体で 約 22-25 秒
- iceberg : 5 repos の ingest 全体で 約 25-30 秒

差は **catalog API 往復 + manifest 書込み**の分、Iceberg が 2-3 秒長い。
個人スケールでは無視できる差。

### 読込み時間（dbt build）

`make dbt-build` 全体（9 models + 19 tests）:
- parquet 経路 (Phase 1): 約 0.9-1.1 秒
- iceberg 経路 (Phase 2B): 約 1.0-1.2 秒

差は **ATTACH lakekeeper + manifest 読込み**の分、Iceberg が 0.1-0.2 秒長い。
dbt run 全体で誤差レベル。

### ファイル数 / バケットの見え方

```
# parquet (s3://bronze/)
bronze/
├── repo_metadata/dt=2026-05-11/repo=anthropics__claude-code/part-*.parquet
├── issue_or_pr/dt=2026-05-11/repo=*/part-*.parquet
└── commit/dt=2026-05-11/repo=*/part-*.parquet

# iceberg (s3://iceberg-warehouse/)
warehouse/<warehouse-id>/<namespace-id>/<table-id>/
├── data/00000-*.parquet                  ← データ本体
├── metadata/v1.metadata.json             ← 最新のスナップショット参照
├── metadata/snap-*-1-*.avro              ← マニフェストリスト
└── metadata/<uuid>.avro                  ← マニフェスト
```

**parquet は `aws s3 ls` で意図が伝わる**。
**Iceberg は専用 tool (PyIceberg CLI / Spark / Trino) で覗かないと中身が見えない**。
これは Iceberg の弱み。デバッグが Garage の web UI 越しではかなり辛い。

## 5. 実装で踏んだ罠（4 つ）

詳細はブログ記事 `.local/phase-2b/article-draft.md` に書いた。要点だけ:

1. **Iceberg field ID は globally unique sequential**。
   List `element_id` を別空間で振ると後で衝突する。
2. **Pydantic v2 → pyarrow は `model_dump(mode='python')`**。
   `mode='json'` は datetime を ISO 文字列にして Arrow キャストを壊す。
3. **warehouse の S3 endpoint は drift する**。
   dev マシンの Wi-Fi 切替で LAN IP が変わると古い endpoint で 408 timeout。
   `lakekeeper-init.sh` を self-healing 仕様に。
4. **dbt `on-run-end: DETACH` は書かない**。
   DuckDB は `DETACH IF EXISTS` を受けない、かつプロセス終了で接続は自動で切れる。

## 6. Iceberg を選んでよかったか — 観点別

### 「もう戻りたくない」ところ

- **schema 進化**: `ALTER TABLE ... ADD COLUMN` が catalog 経由で安全にできる。
  parquet 時代は型 drift で dbt build が落ちる度に手で再生成していた。
- **冪等性**: snapshot 単位の append なので「2 回叩いても結果が同じ」を catalog が保証してくれる。
- **後段の選択肢**: Athena / Trino / Spark / DuckDB が catalog 経由で同じテーブルを読める。
  parquet 時代は「読み手ごとに schema を伝える」必要があった。

### 「parquet のほうが楽だった」ところ

- **デバッグ**: 「行が変だな？」と思ったとき、parquet なら
  `aws s3 cp s3://bronze/... - | parquet-tools cat` で即見える。
  Iceberg は snapshot をたどって manifest を読んで… と手数が多い。
- **学習コスト**: snapshot / partition spec / field id / sort order
  などの概念を全部理解しないと「思った通りに動かない」シーンが出る。
- **bootstrap**: catalog (Lakekeeper) と warehouse 設定が増える。
  Phase 2A で 1 週末溶かした。

## 7. どういうとき Iceberg を選ぶか

「ハイブリッド」が現実的だと思う:

- **本番 / 共有レイヤー**: Iceberg
- **個人の検証 / 一過性のレイヤー**: parquet 直書き

例えば本プロジェクトの場合:
- **bronze (rawに近い、長期保管、複数 reader)**: Iceberg ← Phase 2B でここまで
- **silver (DuckDB local, dbt artifact)**: 一旦 DuckDB native のまま
- **gold (Streamlit が読む集計)**: DuckDB native のまま
- **将来 AWS 移行時 (Phase 6)**: bronze は Glue Catalog の Iceberg として cross-engine 共有

「全部 Iceberg にすればいい」というほど単純ではない。
**読み手と書き手が固定で、schema 進化も少ないレイヤーに Iceberg は過剰投資**。

## 8. 関連 ADR / 記事

- ADR-0010: Iceberg via Lakekeeper (このアーキの意思決定記録)
- Phase 2A blog draft: 「Lakekeeper + PyIceberg + DuckDB をローカルで繋ぐ — 4 つの落とし穴」
- Phase 2B blog draft: 「Bronze 全テーブルを parquet → Iceberg に切替えた話」
- PR: `feat/phase-2b-iceberg-bronze`

## 9. 今後

- **Phase 2C**: 旧 parquet writer 削除、time travel / snapshot expire を 1 度は触る
- **Phase 6**: AWS S3 + Glue Catalog 移行。Iceberg のままなのでテーブル定義は維持できる想定
- **Phase 7 以降**: bronze 以外（silver / gold）の Iceberg 化を ROI 見ながら検討
