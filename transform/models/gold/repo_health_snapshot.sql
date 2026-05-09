{{ config(materialized='table') }}

-- One row per repo with current "vital signs" — used in the Streamlit overview.
select
    r.repo_full_name,
    r.repo_name,
    r.owner_login,
    r.description,
    r.language,
    r.license_spdx,
    r.stargazers_count,
    r.forks_count,
    r.open_issues_count,
    r.watchers_count,
    r.last_pushed_at,
    coalesce(c.recent_commits_28d, 0) as recent_commits_28d,
    coalesce(p.recent_prs_28d, 0) as recent_prs_28d,
    coalesce(i.recent_issues_28d, 0) as recent_issues_28d,
    coalesce(c.recent_authors_28d, 0) as recent_authors_28d,
    r.snapshot_at
from {{ ref('dim_repos') }} r
left join (
    select
        repo_full_name,
        count(*) as recent_commits_28d,
        count(distinct author_login) as recent_authors_28d
    from {{ ref('fct_commits') }}
    where committed_date >= current_date - interval '28 days'
    group by 1
) c using (repo_full_name)
left join (
    select repo_full_name, count(*) as recent_prs_28d
    from {{ ref('fct_pull_requests') }}
    where created_at >= current_date - interval '28 days'
    group by 1
) p using (repo_full_name)
left join (
    select repo_full_name, count(*) as recent_issues_28d
    from {{ ref('fct_issues') }}
    where created_at >= current_date - interval '28 days'
    group by 1
) i using (repo_full_name)
