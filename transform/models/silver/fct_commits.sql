{{ config(materialized='table') }}

with deduped as (
    select
        *,
        row_number() over (
            partition by repo_full_name, sha
            order by fetched_at desc
        ) as rn
    from {{ ref('stg_commit') }}
)
select
    repo_full_name,
    sha,
    message,
    author_login,
    author_email,
    authored_date,
    committer_login,
    committer_email,
    committed_date,
    cardinality(parents) as parent_count,
    fetched_at
from deduped
where rn = 1
