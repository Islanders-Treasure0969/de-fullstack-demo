{{ config(materialized='view') }}

select
    repo_full_name,
    sha,
    message,
    author_login,
    author_email,
    cast(authored_date as timestamp) as authored_date,
    committer_login,
    committer_email,
    cast(committed_date as timestamp) as committed_date,
    parents,
    cast(fetched_at as timestamp) as fetched_at,
    raw_payload
from {{ source('bronze', 'commit') }}
