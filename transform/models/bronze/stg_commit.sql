{{ config(materialized='table') }}

-- Bronze passthrough for commits.
-- Reads via the Lakekeeper Iceberg catalog (ATTACH'd in on-run-start).
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
    parents,
    fetched_at,
    raw_payload
from lakekeeper.bronze.commit
