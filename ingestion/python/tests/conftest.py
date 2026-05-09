"""Shared test fixtures."""

from __future__ import annotations

import pytest

from de_lab_ingestor.config import Settings


@pytest.fixture
def settings(monkeypatch: pytest.MonkeyPatch) -> Settings:
    """Settings instance backed by a clean env (no .env interference)."""
    # Block .env loading so tests are reproducible.
    for var in (
        "GITHUB_TOKEN",
        "GITHUB_TARGET_REPOS",
        "GARAGE_S3_ACCESS_KEY",
        "GARAGE_S3_SECRET_KEY",
    ):
        monkeypatch.delenv(var, raising=False)

    monkeypatch.setenv("GITHUB_TOKEN", "test-token")
    monkeypatch.setenv("GITHUB_TARGET_REPOS", "dbt-labs/dbt-core,apache/iceberg")
    monkeypatch.setenv("GARAGE_S3_ACCESS_KEY", "test-key")
    monkeypatch.setenv("GARAGE_S3_SECRET_KEY", "test-secret")

    # Use an _env_file=None override so the .env from the repo root is ignored.
    return Settings(_env_file=None)  # type: ignore[call-arg]
