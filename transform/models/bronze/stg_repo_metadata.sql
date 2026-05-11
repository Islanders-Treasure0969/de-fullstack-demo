{{ config(materialized='table') }}

-- Bronze passthrough for repository headline numbers.
-- Reads via the Lakekeeper Iceberg catalog (ATTACH'd in on-run-start).
-- The ingestor (Phase 2B) writes here with PyIceberg; Phase 1 wrote
-- Hive-partitioned parquet on Garage — see git history for that variant.
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
    license_spdx,
    archived,
    disabled,
    fork,
    created_at,
    updated_at,
    pushed_at,
    fetched_at,
    raw_payload
from lakekeeper.bronze.repo_metadata
