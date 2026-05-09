{{ config(materialized='table') }}

-- Bronze passthrough for repository headline numbers.
-- Read directly from Garage S3 via DuckDB httpfs + parquet.
-- (sources.yml documents the contract; dbt-duckdb's source resolution
-- doesn't auto-handle Hive-partitioned globs, so we read explicitly.)
select
    full_name as repo_full_name,
    name as repo_name,
    owner_login,
    description,
    stargazers_count,
    forks_count,
    open_issues_count,
    watchers_count,
    subscribers_count,
    network_count,
    default_branch,
    language,
    try_cast(license_spdx as varchar) as license_spdx,
    archived,
    disabled,
    fork,
    cast(created_at as timestamp) as created_at,
    cast(updated_at as timestamp) as updated_at,
    cast(pushed_at as timestamp) as pushed_at,
    cast(fetched_at as timestamp) as fetched_at,
    raw_payload
from read_parquet(
    's3://bronze/repo_metadata/**/*.parquet',
    hive_partitioning = true,
    union_by_name = true
)
