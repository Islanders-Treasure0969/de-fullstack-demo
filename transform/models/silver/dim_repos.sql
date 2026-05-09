{{ config(materialized='table') }}

-- Latest snapshot per repo. Bronze can have multiple snapshots over time;
-- silver collapses to "current truth" by fetched_at.
with ranked as (
    select
        *,
        row_number() over (
            partition by repo_full_name
            order by fetched_at desc
        ) as rn
    from {{ ref('stg_repo_metadata') }}
)
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
from ranked
where rn = 1
