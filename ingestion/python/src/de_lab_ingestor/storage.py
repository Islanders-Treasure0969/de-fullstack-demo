"""S3 / Garage writer for Bronze parquet partitions.

Layout (Hive-style):
    bronze/<event_type>/<owner>/<repo>/year=YYYY/month=MM/day=DD/<run_id>.parquet

Why Hive-style? DuckDB and pyarrow datasets both pick partitions up automatically,
and dbt sources can declare them with an external location.
"""

from __future__ import annotations

import io
import json
import uuid
from collections.abc import Iterable
from datetime import UTC, datetime
from typing import TYPE_CHECKING

import boto3
import pyarrow as pa
import pyarrow.parquet as pq
import structlog
from botocore.client import Config

from .config import Settings

if TYPE_CHECKING:
    from pydantic import BaseModel

log = structlog.get_logger(__name__)

EventType = str  # "repo_metadata" | "issue_or_pr" | "commit"


class BronzeWriter:
    """Writes parquet to a Garage / LocalStack S3-compatible bucket.

    A single instance can be reused across writes within a single run.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = boto3.client(
            "s3",
            endpoint_url=settings.garage_s3_endpoint,
            aws_access_key_id=settings.garage_s3_access_key.get_secret_value(),
            aws_secret_access_key=settings.garage_s3_secret_key.get_secret_value(),
            region_name=settings.garage_s3_region,
            config=Config(
                signature_version="s3v4",
                s3={"addressing_style": "path"},  # Garage requires path-style
            ),
        )
        self._run_id = uuid.uuid4().hex[:12]

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def ensure_bucket(self) -> None:
        """Idempotently create the bronze bucket."""
        bucket = self._settings.bronze_bucket
        try:
            self._client.head_bucket(Bucket=bucket)
            log.debug("bucket_exists", bucket=bucket)
        except self._client.exceptions.ClientError:
            self._client.create_bucket(Bucket=bucket)
            log.info("bucket_created", bucket=bucket)

    def write(
        self,
        event_type: EventType,
        repo_full_name: str,
        records: Iterable[BaseModel],
        partition_date: datetime | None = None,
    ) -> int:
        """Serialize `records` to Parquet and upload. Returns row count.

        Returns 0 (and writes nothing) when records is empty — this is intentional
        so callers can naively pass possibly-empty iterables.
        """
        owner, repo = repo_full_name.split("/", 1)
        partition_date = (partition_date or datetime.now(tz=UTC)).astimezone(UTC)
        rows = [_to_arrow_row(r) for r in records]
        if not rows:
            log.info("write_skipped_empty", event_type=event_type, repo=repo_full_name)
            return 0

        table = pa.Table.from_pylist(rows)
        buf = io.BytesIO()
        pq.write_table(table, buf, compression="zstd")
        buf.seek(0)

        key = (
            f"{event_type}/{owner}/{repo}"
            f"/year={partition_date.year:04d}"
            f"/month={partition_date.month:02d}"
            f"/day={partition_date.day:02d}"
            f"/{self._run_id}.parquet"
        )
        self._client.put_object(
            Bucket=self._settings.bronze_bucket,
            Key=key,
            Body=buf.getvalue(),
            ContentType="application/octet-stream",
        )
        log.info(
            "write_ok",
            event_type=event_type,
            repo=repo_full_name,
            rows=len(rows),
            key=key,
        )
        return len(rows)


def _to_arrow_row(model: BaseModel) -> dict[str, object]:
    """Convert a Pydantic model to a flat dict suitable for pyarrow.

    The `raw_payload` field is serialized to JSON so it can land as a string
    column without exploding the schema.
    """
    row = model.model_dump(mode="json")
    if "raw_payload" in row and not isinstance(row["raw_payload"], str):
        row["raw_payload"] = json.dumps(row["raw_payload"], ensure_ascii=False)
    return row
