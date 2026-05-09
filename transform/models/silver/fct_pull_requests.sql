{{ config(materialized='table') }}

with deduped as (
    select
        *,
        row_number() over (
            partition by repo_full_name, number
            order by fetched_at desc
        ) as rn
    from {{ ref('stg_issue_or_pr') }}
    where is_pull_request = true
)
select
    repo_full_name,
    number as pr_number,
    state,
    title,
    user_login as author_login,
    labels,
    assignees,
    comments,
    created_at,
    updated_at,
    closed_at,
    fetched_at
from deduped
where rn = 1
