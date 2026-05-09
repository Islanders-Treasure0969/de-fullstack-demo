{{ config(materialized='table') }}

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
    -- DuckDB v1.5: cardinality() is for MAPs; use len() for LISTs
    len(parents) as parent_count,
    fetched_at
from {{ ref('stg_commit') }}
qualify row_number() over (partition by repo_full_name, sha order by fetched_at desc) = 1
