{{ config(materialized='table') }}

-- Bronze passthrough for issues + PRs (GitHub treats them via the same endpoint).
-- Splitting into fct_issues / fct_pull_requests happens in silver.
-- Reads via the Lakekeeper Iceberg catalog (ATTACH'd in on-run-start).
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
    created_at,
    updated_at,
    closed_at,
    fetched_at,
    raw_payload
from lakekeeper.bronze.issue_or_pr
