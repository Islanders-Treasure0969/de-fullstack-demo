{{ config(materialized='table') }}

-- The headline gold table consumed by the Streamlit dashboard.
-- One row per (repo, date), with counts derived from silver.

with dates as (
    -- Distinct activity days observed across all silver tables.
    select repo_full_name, date_trunc('day', created_at)::date as day
    from {{ ref('fct_issues') }}
    union
    select repo_full_name, date_trunc('day', created_at)::date as day
    from {{ ref('fct_pull_requests') }}
    union
    select repo_full_name, date_trunc('day', committed_date)::date as day
    from {{ ref('fct_commits') }}
    where committed_date is not null
),

issues_daily as (
    select
        repo_full_name,
        date_trunc('day', created_at)::date as day,
        count(*) as issues_opened,
        count(*) filter (where closed_at is not null
                         and date_trunc('day', closed_at) = date_trunc('day', created_at)
        ) as issues_closed_same_day
    from {{ ref('fct_issues') }}
    group by 1, 2
),

prs_daily as (
    select
        repo_full_name,
        date_trunc('day', created_at)::date as day,
        count(*) as prs_opened,
        count(*) filter (where state = 'closed') as prs_closed
    from {{ ref('fct_pull_requests') }}
    group by 1, 2
),

commits_daily as (
    select
        repo_full_name,
        date_trunc('day', committed_date)::date as day,
        count(*) as commits,
        count(distinct author_login) as distinct_authors
    from {{ ref('fct_commits') }}
    where committed_date is not null
    group by 1, 2
)

select
    d.repo_full_name,
    d.day,
    coalesce(i.issues_opened, 0) as issues_opened,
    coalesce(i.issues_closed_same_day, 0) as issues_closed_same_day,
    coalesce(p.prs_opened, 0) as prs_opened,
    coalesce(p.prs_closed, 0) as prs_closed,
    coalesce(c.commits, 0) as commits,
    coalesce(c.distinct_authors, 0) as distinct_authors
from dates d
left join issues_daily i using (repo_full_name, day)
left join prs_daily p using (repo_full_name, day)
left join commits_daily c using (repo_full_name, day)
order by d.repo_full_name, d.day
