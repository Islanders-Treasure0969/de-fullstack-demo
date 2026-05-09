{{ config(materialized='view') }}

-- Bronze passthrough for repository headline numbers.
-- Just type cast and rename for downstream consumption.
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
    cast(created_at as timestamp) as created_at,
    cast(updated_at as timestamp) as updated_at,
    cast(pushed_at as timestamp) as pushed_at,
    cast(fetched_at as timestamp) as fetched_at,
    raw_payload
from {{ source('bronze', 'repo_metadata') }}
