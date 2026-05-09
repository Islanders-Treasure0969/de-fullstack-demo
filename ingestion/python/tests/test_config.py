"""Settings parsing tests."""

from __future__ import annotations

from de_lab_ingestor.config import Settings


def test_target_repos_parsing(settings: Settings) -> None:
    assert settings.target_repos == ["dbt-labs/dbt-core", "apache/iceberg"]


def test_target_repos_handles_whitespace_and_empty(monkeypatch) -> None:
    monkeypatch.setenv("GITHUB_TARGET_REPOS", "  a/b , , c/d  ")
    s = Settings(_env_file=None)  # type: ignore[call-arg]
    assert s.target_repos == ["a/b", "c/d"]
