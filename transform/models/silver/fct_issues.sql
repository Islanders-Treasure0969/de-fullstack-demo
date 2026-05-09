{{ config(materialized='table') }}

-- Issues only. PRs are split off into fct_pull_requests.
with deduped as (
    select
        *,
        row_number() over (
            partition by repo_full_name, number
            order by fetched_at desc
        ) as rn
    from {{ ref('stg_issue_or_pr') }}
    where is_pull_request = false
)
select
    repo_full_name,
    number as issue_number,
    state,
    title,
    user_login as author_login,
    locked,
    labels,
    assignees,
    comments,
    created_at,
    updated_at,
    closed_at,
    fetched_at
from deduped
where rn = 1
