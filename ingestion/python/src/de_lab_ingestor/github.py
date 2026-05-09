"""GitHub REST API client.

Why this looks the way it does:
- httpx async client for parallelism (Phase 3 will scale this up)
- tenacity for retry on 5xx and connection errors only
- explicit rate-limit handling: we read X-RateLimit-Remaining and sleep when low
- pagination via Link header parsing (not hand-built)
"""

from __future__ import annotations

import asyncio
import re
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from typing import Any

import httpx
import structlog
from tenacity import (
    AsyncRetrying,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from .config import Settings
from .models import Commit, IssueOrPR, RepoMetadata

log = structlog.get_logger(__name__)

_LINK_NEXT_RE = re.compile(r'<([^>]+)>;\s*rel="next"')


class GitHubClient:
    """Thin wrapper around httpx tuned for the GitHub REST API."""

    def __init__(self, settings: Settings, client: httpx.AsyncClient | None = None) -> None:
        self._settings = settings
        self._client = client or httpx.AsyncClient(
            base_url=settings.github_api_base,
            timeout=settings.request_timeout_seconds,
            headers={
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": settings.github_user_agent,
                "Authorization": f"Bearer {settings.github_token.get_secret_value()}",
            },
        )

    async def __aenter__(self) -> GitHubClient:
        return self

    async def __aexit__(self, *_exc_info: object) -> None:
        await self._client.aclose()

    # --------------------------------------------------------------
    # Public methods
    # --------------------------------------------------------------
    async def get_repo_metadata(self, full_name: str) -> RepoMetadata:
        payload = await self._get(f"/repos/{full_name}")
        return _to_repo_metadata(payload)

    async def list_issues(
        self,
        full_name: str,
        since: datetime | None = None,
    ) -> AsyncIterator[IssueOrPR]:
        params: dict[str, Any] = {"state": "all", "per_page": 100}
        if since is not None:
            params["since"] = since.replace(tzinfo=UTC).isoformat()
        async for item in self._paginate(f"/repos/{full_name}/issues", params=params):
            yield _to_issue_or_pr(full_name, item)

    async def list_commits(
        self,
        full_name: str,
        since: datetime | None = None,
    ) -> AsyncIterator[Commit]:
        params: dict[str, Any] = {"per_page": 100}
        if since is not None:
            params["since"] = since.replace(tzinfo=UTC).isoformat()
        async for item in self._paginate(f"/repos/{full_name}/commits", params=params):
            yield _to_commit(full_name, item)

    # --------------------------------------------------------------
    # Internals
    # --------------------------------------------------------------
    async def _get(self, path: str, params: dict[str, Any] | None = None) -> Any:
        async for attempt in AsyncRetrying(
            stop=stop_after_attempt(self._settings.max_retries),
            wait=wait_exponential(multiplier=1.5, min=1, max=30),
            retry=retry_if_exception_type((httpx.HTTPError, _RetryableStatus)),
            reraise=True,
        ):
            with attempt:
                response = await self._client.get(path, params=params)
                await self._respect_rate_limit(response)
                if 500 <= response.status_code < 600:
                    raise _RetryableStatus(response.status_code)
                response.raise_for_status()
                return response.json()
        msg = "unreachable: tenacity should reraise"
        raise RuntimeError(msg)

    async def _paginate(
        self,
        path: str,
        params: dict[str, Any] | None = None,
    ) -> AsyncIterator[dict[str, Any]]:
        # First request goes through the retrying _get; subsequent pages follow
        # Link headers but we still want retry semantics, so reuse _get_raw.
        url: str | None = path
        next_params = params
        while url:
            response = await self._get_response(url, params=next_params)
            for item in response.json():
                yield item
            link = response.headers.get("Link", "")
            match = _LINK_NEXT_RE.search(link)
            url = match.group(1) if match else None
            next_params = None  # next URL already encodes params

    async def _get_response(
        self, path_or_url: str, params: dict[str, Any] | None
    ) -> httpx.Response:
        async for attempt in AsyncRetrying(
            stop=stop_after_attempt(self._settings.max_retries),
            wait=wait_exponential(multiplier=1.5, min=1, max=30),
            retry=retry_if_exception_type((httpx.HTTPError, _RetryableStatus)),
            reraise=True,
        ):
            with attempt:
                response = await self._client.get(path_or_url, params=params)
                await self._respect_rate_limit(response)
                if 500 <= response.status_code < 600:
                    raise _RetryableStatus(response.status_code)
                response.raise_for_status()
                return response
        msg = "unreachable"
        raise RuntimeError(msg)

    async def _respect_rate_limit(self, response: httpx.Response) -> None:
        """If we're about to be throttled, sleep until the window resets."""
        remaining = response.headers.get("X-RateLimit-Remaining")
        reset = response.headers.get("X-RateLimit-Reset")
        if remaining is None or reset is None:
            return
        try:
            remaining_int = int(remaining)
            reset_ts = int(reset)
        except ValueError:
            return
        if remaining_int > 5:
            return
        now = int(datetime.now(tz=UTC).timestamp())
        wait = max(0, reset_ts - now) + 1
        log.warning(
            "rate_limit_low",
            remaining=remaining_int,
            sleeping_for=wait,
        )
        await asyncio.sleep(wait)


class _RetryableStatus(Exception):
    """Marker for 5xx responses we want tenacity to retry."""


# --------------------------------------------------------------
# Mappers — keep wire format <-> domain model conversion in one place
# --------------------------------------------------------------


def _to_repo_metadata(payload: dict[str, Any]) -> RepoMetadata:
    return RepoMetadata(
        full_name=payload["full_name"],
        name=payload["name"],
        owner_login=payload["owner"]["login"],
        description=payload.get("description"),
        stargazers_count=payload.get("stargazers_count", 0),
        forks_count=payload.get("forks_count", 0),
        open_issues_count=payload.get("open_issues_count", 0),
        watchers_count=payload.get("watchers_count", 0),
        subscribers_count=payload.get("subscribers_count", 0),
        network_count=payload.get("network_count", 0),
        default_branch=payload.get("default_branch", "main"),
        language=payload.get("language"),
        license_spdx=(payload.get("license") or {}).get("spdx_id"),
        archived=payload.get("archived", False),
        disabled=payload.get("disabled", False),
        fork=payload.get("fork", False),
        created_at=payload.get("created_at"),
        updated_at=payload.get("updated_at"),
        pushed_at=payload.get("pushed_at"),
        fetched_at=datetime.now(tz=UTC),
        raw_payload=payload,
    )


def _to_issue_or_pr(repo_full_name: str, payload: dict[str, Any]) -> IssueOrPR:
    return IssueOrPR(
        repo_full_name=repo_full_name,
        number=payload["number"],
        state=payload["state"],
        title=payload["title"],
        user_login=(payload.get("user") or {}).get("login"),
        is_pull_request=("pull_request" in payload),
        locked=payload.get("locked", False),
        labels=[lbl["name"] for lbl in payload.get("labels", [])],
        assignees=[a["login"] for a in payload.get("assignees", [])],
        comments=payload.get("comments", 0),
        created_at=payload["created_at"],
        updated_at=payload["updated_at"],
        closed_at=payload.get("closed_at"),
        fetched_at=datetime.now(tz=UTC),
        raw_payload=payload,
    )


def _to_commit(repo_full_name: str, payload: dict[str, Any]) -> Commit:
    commit = payload.get("commit") or {}
    author = commit.get("author") or {}
    committer = commit.get("committer") or {}
    return Commit(
        repo_full_name=repo_full_name,
        sha=payload["sha"],
        message=commit.get("message", ""),
        author_login=(payload.get("author") or {}).get("login"),
        author_email=author.get("email"),
        authored_date=author.get("date"),
        committer_login=(payload.get("committer") or {}).get("login"),
        committer_email=committer.get("email"),
        committed_date=committer.get("date"),
        parents=[p["sha"] for p in payload.get("parents", [])],
        fetched_at=datetime.now(tz=UTC),
        raw_payload=payload,
    )
