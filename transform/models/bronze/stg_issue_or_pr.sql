{{ config(materialized='table') }}

-- Bronze passthrough for issues + PRs (GitHub treats them via the same endpoint).
-- Splitting happens in silver.
select
    repo_full_name,
    number,
    state,
    title,
    user_login,
    is_pull_request,
    locked,
    labels,
    assignees,
    comments,
    cast(created_at as timestamp) as created_at,
    cast(updated_at as timestamp) as updated_at,
    cast(closed_at as timestamp) as closed_at,
    cast(fetched_at as timestamp) as fetched_at,
    raw_payload
from read_parquet(
    's3://bronze/issue_or_pr/**/*.parquet',
    hive_partitioning = true,
    union_by_name = true
)
