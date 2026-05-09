"""Phase 1 Streamlit dashboard for the OSS Activity Observatory.

Reads gold models from DuckDB. The DuckDB file is created by `dbt build`
in the transform/ project (path configured in profiles.yml).
"""

from __future__ import annotations

import os
from pathlib import Path

import altair as alt
import duckdb
import pandas as pd
import streamlit as st

DEFAULT_DB = Path(__file__).resolve().parents[2] / "docker" / "data" / "de_lab.duckdb"
DB_PATH = Path(os.environ.get("DUCKDB_PATH", str(DEFAULT_DB)))

st.set_page_config(
    page_title="de-fullstack-demo · OSS Activity Observatory",
    layout="wide",
    initial_sidebar_state="expanded",
)


@st.cache_resource
def _connect(path: Path) -> duckdb.DuckDBPyConnection:
    return duckdb.connect(str(path), read_only=True)


@st.cache_data(ttl=300)
def _query(sql: str) -> pd.DataFrame:
    return _connect(DB_PATH).execute(sql).fetch_df()


# --------------------------------------------------------------
# Layout
# --------------------------------------------------------------
st.title(":bar_chart: OSS Activity Observatory")
st.caption("Phase 1 dashboard — daily activity across selected OSS repositories.")

if not DB_PATH.exists():
    st.error(f"DuckDB file not found at `{DB_PATH}`. Run `make ingest && make dbt-build` first.")
    st.stop()

# --------------------------------------------------------------
# Repo health overview
# --------------------------------------------------------------
try:
    health = _query("select * from gold.repo_health_snapshot order by stargazers_count desc")
except duckdb.CatalogException:
    st.warning("Gold models not yet materialized. Run `make dbt-build` after the first ingest.")
    st.stop()

st.subheader("Repository health snapshot")
col1, col2, col3, col4 = st.columns(4)
col1.metric("Repos tracked", len(health))
col2.metric("Total stars", int(health["stargazers_count"].sum()))
col3.metric("Recent commits (28d)", int(health["recent_commits_28d"].sum()))
col4.metric("Recent PRs (28d)", int(health["recent_prs_28d"].sum()))
st.dataframe(health, hide_index=True, use_container_width=True)

# --------------------------------------------------------------
# Daily activity chart
# --------------------------------------------------------------
st.subheader("Daily activity")
selected = st.multiselect(
    "Repositories",
    options=health["repo_full_name"].tolist(),
    default=health["repo_full_name"].head(5).tolist(),
)

if selected:
    placeholders = ",".join(f"'{r}'" for r in selected)
    daily = _query(
        f"""
        select repo_full_name, day, commits, prs_opened, issues_opened
        from gold.repo_daily_metrics
        where repo_full_name in ({placeholders})
        order by day
        """
    )
    melted = daily.melt(
        id_vars=["repo_full_name", "day"],
        value_vars=["commits", "prs_opened", "issues_opened"],
        var_name="metric",
        value_name="count",
    )
    chart = (
        alt.Chart(melted)
        .mark_line(point=True)
        .encode(
            x="day:T",
            y="count:Q",
            color="repo_full_name:N",
            strokeDash="metric:N",
            tooltip=["repo_full_name", "day", "metric", "count"],
        )
        .properties(height=400)
        .interactive()
    )
    st.altair_chart(chart, use_container_width=True)
else:
    st.info("Select at least one repository.")
