"""Settings loaded from environment / .env.

Reads the repo-root `.env` so secrets stay out of git. Strict typing via
Pydantic so a missing/typo'd variable fails fast at startup.
"""

from __future__ import annotations

from pathlib import Path

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

# Repo-root .env (this file is at ingestion/python/src/de_lab_ingestor/config.py).
REPO_ROOT = Path(__file__).resolve().parents[4]


class Settings(BaseSettings):
    """All configuration the ingestor needs."""

    model_config = SettingsConfigDict(
        env_file=str(REPO_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ---------------- GitHub ----------------
    github_token: SecretStr = Field(
        default=SecretStr(""),
        description="PAT with `public_repo` read scope",
    )
    github_target_repos: str = Field(
        default="",
        description="Comma-separated 'owner/repo' list",
    )
    github_api_base: str = Field(default="https://api.github.com")
    github_user_agent: str = Field(default="de-lab-ingestor/0.1.0")

    # ---------------- Garage / S3 ----------------
    garage_s3_endpoint: str = Field(default="http://localhost:3900")
    garage_s3_access_key: SecretStr = Field(default=SecretStr(""))
    garage_s3_secret_key: SecretStr = Field(default=SecretStr(""))
    garage_s3_region: str = Field(default="garage")
    bronze_bucket: str = Field(default="bronze")

    # ---------------- Runtime ----------------
    log_level: str = Field(default="INFO")
    request_timeout_seconds: float = Field(default=30.0)
    max_retries: int = Field(default=5)

    @property
    def target_repos(self) -> list[str]:
        """Parsed list of target repos. Filters empty / whitespace entries."""
        return [r.strip() for r in self.github_target_repos.split(",") if r.strip()]


def get_settings() -> Settings:
    """Module-level loader. Avoid creating multiple instances within one run."""
    return Settings()
