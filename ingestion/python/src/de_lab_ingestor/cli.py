"""Typer-based CLI.

Commands:
    de-lab-ingestor bootstrap      Create the bronze bucket
    de-lab-ingestor ingest         Pull all configured repos
    de-lab-ingestor ingest --repo dbt-labs/dbt-core
"""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Annotated

import structlog
import typer

from .config import get_settings
from .github import GitHubClient
from .logging import configure as configure_logging
from .storage import BronzeWriter

app = typer.Typer(no_args_is_help=True, add_completion=False, pretty_exceptions_show_locals=False)
log = structlog.get_logger(__name__)


@app.callback()
def _root() -> None:
    """de-lab-ingestor — Phase 1 GitHub OSS activity ingestor."""
    settings = get_settings()
    configure_logging(settings.log_level)


@app.command()
def bootstrap() -> None:
    """Create the bronze bucket on Garage / LocalStack."""
    writer = BronzeWriter(get_settings())
    writer.ensure_bucket()
    log.info("bootstrap_done")


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

    since = datetime.now(tz=UTC) - timedelta(days=since_days)
    asyncio.run(_run(targets, since))


async def _run(targets: list[str], since: datetime) -> None:
    settings = get_settings()
    writer = BronzeWriter(settings)
    writer.ensure_bucket()

    async with GitHubClient(settings) as gh:
        for full_name in targets:
            log.info("ingest_start", repo=full_name, since=since.isoformat())
            metadata = await gh.get_repo_metadata(full_name)
            writer.write("repo_metadata", full_name, [metadata])

            issues = [item async for item in gh.list_issues(full_name, since=since)]
            writer.write("issue_or_pr", full_name, issues)

            commits = [item async for item in gh.list_commits(full_name, since=since)]
            writer.write("commit", full_name, commits)
            log.info("ingest_done", repo=full_name)
