"""Pydantic models for the GitHub event payloads we capture into Bronze.

These are *narrow* projections — only fields that downstream dbt models will
use. The full payload is preserved separately in the `raw_payload` JSON column
to allow re-derivation without re-fetching.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class _Base(BaseModel):
    """Common config for all models."""

    model_config = ConfigDict(
        extra="ignore",
        populate_by_name=True,
    )


class RepoMetadata(_Base):
    """Snapshot of a repository's headline numbers."""

    full_name: str
    name: str
    owner_login: str = Field(alias="owner_login")
    description: str | None = None
    stargazers_count: int = 0
    forks_count: int = 0
    open_issues_count: int = 0
    watchers_count: int = 0
    subscribers_count: int = 0
    network_count: int = 0
    default_branch: str = "main"
    language: str | None = None
    license_spdx: str | None = None
    archived: bool = False
    disabled: bool = False
    fork: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None
    pushed_at: datetime | None = None
    fetched_at: datetime
    raw_payload: dict[str, Any]


class IssueOrPR(_Base):
    """Issue or pull request. GitHub treats both via the issues endpoint
    so we ingest them together and split downstream.
    """

    repo_full_name: str
    number: int
    state: str  # "open" | "closed"
    title: str
    user_login: str | None = None
    is_pull_request: bool
    locked: bool = False
    labels: list[str] = Field(default_factory=list)
    assignees: list[str] = Field(default_factory=list)
    comments: int = 0
    created_at: datetime
    updated_at: datetime
    closed_at: datetime | None = None
    fetched_at: datetime
    raw_payload: dict[str, Any]


class Commit(_Base):
    """Commit on the default branch (Phase 1 scope)."""

    repo_full_name: str
    sha: str
    message: str
    author_login: str | None = None
    author_email: str | None = None
    authored_date: datetime | None = None
    committer_login: str | None = None
    committer_email: str | None = None
    committed_date: datetime | None = None
    parents: list[str] = Field(default_factory=list)
    fetched_at: datetime
    raw_payload: dict[str, Any]
