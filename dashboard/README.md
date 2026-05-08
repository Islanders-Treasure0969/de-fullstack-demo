# dashboard/

社内・分析者向けの Streamlit ダッシュボード。

## 起動 (Phase 1+)

```bash
cd dashboard/streamlit
uv venv && source .venv/bin/activate
uv pip install -r requirements.txt
streamlit run app.py
```

DuckDB の gold layer を直接読む。Phase 5 で構築する Next.js アプリは別目的（外部公開・Reverse ETL 経由の operational data）。
