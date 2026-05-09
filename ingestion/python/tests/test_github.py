"""GitHub client tests using respx for HTTP mocking."""

from __future__ import annotations

import httpx
import pytest
import respx

from de_lab_ingestor.config import Settings
from de_lab_ingestor.github import GitHubClient

REPO = "anthropics/claude-code"


@pytest.fixture
def repo_metadata_payload() -> dict[str, object]:
    return {
        "full_name": REPO,
        "name": "claude-code",
        "owner": {"login": "anthropics"},
        "description": "an agentic coding tool",
        "stargazers_count": 12345,
        "forks_count": 678,
        "open_issues_count": 90,
        "watchers_count": 12345,
        "subscribers_count": 100,
        "network_count": 678,
        "default_branch": "main",
        "language": "TypeScript",
        "license": {"spdx_id": "MIT"},
        "archived": False,
        "disabled": False,
        "fork": False,
        "created_at": "2024-09-01T00:00:00Z",
        "updated_at": "2026-05-01T00:00:00Z",
        "pushed_at": "2026-05-08T00:00:00Z",
    }


async def test_get_repo_metadata_maps_payload(
    settings: Settings,
    repo_metadata_payload: dict[str, object],
) -> None:
    async with respx.mock(base_url=settings.github_api_base) as router:
        router.get(f"/repos/{REPO}").mock(
            return_value=httpx.Response(
                200,
                json=repo_metadata_payload,
                headers={"X-RateLimit-Remaining": "4900", "X-RateLimit-Reset": "0"},
            )
        )
        async with GitHubClient(settings) as gh:
            meta = await gh.get_repo_metadata(REPO)

    assert meta.full_name == REPO
    assert meta.stargazers_count == 12345
    assert meta.license_spdx == "MIT"
    assert meta.raw_payload == repo_metadata_payload


async def test_5xx_is_retried(settings: Settings) -> None:
    """A single 500 should be retried and the second 200 honored."""
    async with respx.mock(base_url=settings.github_api_base) as router:
        route = router.get(f"/repos/{REPO}")
        route.side_effect = [
            httpx.Response(500, headers={"X-RateLimit-Remaining": "100", "X-RateLimit-Reset": "0"}),
            httpx.Response(
                200,
                json={
                    "full_name": REPO,
                    "name": "claude-code",
                    "owner": {"login": "anthropics"},
                },
                headers={"X-RateLimit-Remaining": "100", "X-RateLimit-Reset": "0"},
            ),
        ]
        async with GitHubClient(settings) as gh:
            meta = await gh.get_repo_metadata(REPO)

    assert meta.full_name == REPO
    assert route.call_count == 2
