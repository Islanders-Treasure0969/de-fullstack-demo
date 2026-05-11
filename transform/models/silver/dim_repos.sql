{{ config(materialized='table') }}

-- Latest snapshot per repo. Bronze can have multiple snapshots over time;
-- silver collapses to "current truth" by fetched_at.
--
-- We use `qualify` rather than `with ranked as (select *, row_number() ...)`
-- because `select *` against an external-parquet view confuses DuckDB's
-- window-function binder (INTERNAL Error: TIMESTAMP != VARCHAR).
select
    repo_full_name,
    repo_name,
    owner_login,
    description,
    stargazers_count,
    forks_count,
    open_issues_count,
    watchers_count,
    default_branch,
    language,
    license_spdx,
    archived,
    disabled,
    fork as is_fork,
    created_at as repo_created_at,
    updated_at as repo_updated_at,
    pushed_at as last_pushed_at,
    fetched_at as snapshot_at
from {{ ref('stg_repo_metadata') }}
qualify row_number() over (partition by repo_full_name order by fetched_at desc) = 1
