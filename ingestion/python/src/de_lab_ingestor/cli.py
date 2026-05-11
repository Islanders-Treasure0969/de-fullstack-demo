"""Typer-based CLI.

Commands:
    de-lab-ingestor bootstrap                     Create the bronze sink
    de-lab-ingestor ingest                        Pull all configured repos
    de-lab-ingestor ingest --repo dbt-labs/dbt-core
    de-lab-ingestor ingest --backend parquet      Phase 1 path (legacy)
    de-lab-ingestor ingest --backend iceberg      Phase 2B path (default)
"""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Annotated

import structlog
import typer

from .config import Settings, get_settings
from .github import GitHubClient
from .iceberg_storage import IcebergBronzeWriter
from .logging import configure as configure_logging
from .storage import BronzeWriter

app = typer.Typer(no_args_is_help=True, add_completion=False, pretty_exceptions_show_locals=False)
log = structlog.get_logger(__name__)


@app.callback()
def _root() -> None:
    """de-lab-ingestor — GitHub OSS activity ingestor."""
    settings = get_settings()
    configure_logging(settings.log_level)


def _make_writer(settings: Settings, backend: str) -> BronzeWriter | IcebergBronzeWriter:
    """Pick a writer based on the backend flag.

    Both writers expose `.ensure_bucket()` and `.write(event_type, repo,
    records)` so callers don't care which is in use.
    """
    if backend == "iceberg":
        return IcebergBronzeWriter(settings)
    if backend == "parquet":
        return BronzeWriter(settings)
    msg = f"Unknown backend: {backend!r} (expected iceberg or parquet)"
    raise typer.BadParameter(msg)


@app.command()
def bootstrap(
    backend: Annotated[
        str,
        typer.Option(help="iceberg (default, Phase 2B+) | parquet (Phase 1 legacy)"),
    ] = "",
) -> None:
    """Create the bronze sink (namespace+tables for iceberg, bucket for parquet)."""
    settings = get_settings()
    effective = backend or settings.bronze_backend
    writer = _make_writer(settings, effective)
    writer.ensure_bucket()
    log.info("bootstrap_done", backend=effective)


@app.command()
def ingest(
    repo: Annotated[
        str | None,
        typer.Option(help="Override target repos with a single owner/repo"),
    ] = None,
    since_days: Annotated[
        int,
        typer.Option(help="How many days back to fetch issues/commits"),
    ] = 7,
    backend: Annotated[
        str,
        typer.Option(help="iceberg (default, Phase 2B+) | parquet (Phase 1 legacy)"),
    ] = "",
) -> None:
    """Fetch repo metadata + issues + commits and write to Bronze."""
    settings = get_settings()
    targets = [repo] if repo else settings.target_repos
    if not targets:
        typer.echo(
            "No targets. Set GITHUB_TARGET_REPOS in .env or pass --repo owner/name.",
            err=True,
        )
        raise typer.Exit(code=1)
    if not settings.github_token.get_secret_value():
        typer.echo("GITHUB_TOKEN is empty. Set it in .env first.", err=True)
        raise typer.Exit(code=1)

    effective = backend or settings.bronze_backend
    since = datetime.now(tz=UTC) - timedelta(days=since_days)
    asyncio.run(_run(targets, since, effective))


async def _run(targets: list[str], since: datetime, backend: str) -> None:
    settings = get_settings()
    writer = _make_writer(settings, backend)
    writer.ensure_bucket()

    async with GitHubClient(settings) as gh:
        for full_name in targets:
            log.info("ingest_start", repo=full_name, since=since.isoformat(), backend=backend)
            metadata = await gh.get_repo_metadata(full_name)
            writer.write("repo_metadata", full_name, [metadata])

            issues = [item async for item in gh.list_issues(full_name, since=since)]
            writer.write("issue_or_pr", full_name, issues)

            commits = [item async for item in gh.list_commits(full_name, since=since)]
            writer.write("commit", full_name, commits)
            log.info("ingest_done", repo=full_name)
