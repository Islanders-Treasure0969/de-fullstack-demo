"""Iceberg writer for the Bronze layer (Phase 2B+).

Talks to Lakekeeper's REST catalog and appends Arrow batches to three
Iceberg tables: `bronze.repo_metadata`, `bronze.issue_or_pr`,
`bronze.commit`. Each call to `write()` produces a new Iceberg snapshot,
so the table accumulates history naturally (Iceberg's append semantics
replace Phase 1's Hive-partitioned parquet files).

Schema policy
-------------
Unlike `BronzeWriter` (Phase 1, parquet) which let pyarrow infer types
from samples, this writer pins explicit schemas. That eliminates the
type-drift bug we hit in Phase 1 where `license_spdx=null` for one repo
caused pyarrow to infer the column as INTEGER while every other repo
wrote VARCHAR.

References
----------
- ADR-0010: Iceberg via Lakekeeper
- scripts/iceberg-poc.py: minimal end-to-end smoke test
"""

from __future__ import annotations

import json
from collections.abc import Iterable
from typing import TYPE_CHECKING

import pyarrow as pa
import structlog
from pyiceberg.catalog.rest import RestCatalog
from pyiceberg.exceptions import NamespaceAlreadyExistsError, NoSuchTableError
from pyiceberg.schema import Schema
from pyiceberg.types import (
    BooleanType,
    IntegerType,
    ListType,
    LongType,
    NestedField,
    StringType,
    TimestamptzType,
)

from .config import Settings

if TYPE_CHECKING:
    from pydantic import BaseModel

log = structlog.get_logger(__name__)


# --------------------------------------------------------------
# Iceberg schemas — one per event type. Field ids start at 1 and never
# repeat (Iceberg's column tracking depends on stable ids).
# --------------------------------------------------------------
REPO_METADATA_SCHEMA = Schema(
    NestedField(1, "full_name", StringType(), required=True),
    NestedField(2, "name", StringType(), required=True),
    NestedField(3, "owner_login", StringType(), required=True),
    NestedField(4, "description", StringType()),
    NestedField(5, "stargazers_count", LongType()),
    NestedField(6, "forks_count", LongType()),
    NestedField(7, "open_issues_count", LongType()),
    NestedField(8, "watchers_count", LongType()),
    NestedField(9, "subscribers_count", LongType()),
    NestedField(10, "network_count", LongType()),
    NestedField(11, "default_branch", StringType()),
    NestedField(12, "language", StringType()),
    NestedField(13, "license_spdx", StringType()),
    NestedField(14, "archived", BooleanType()),
    NestedField(15, "disabled", BooleanType()),
    NestedField(16, "fork", BooleanType()),
    NestedField(17, "created_at", TimestamptzType()),
    NestedField(18, "updated_at", TimestamptzType()),
    NestedField(19, "pushed_at", TimestamptzType()),
    NestedField(20, "fetched_at", TimestamptzType(), required=True),
    NestedField(21, "raw_payload", StringType()),
)

ISSUE_OR_PR_SCHEMA = Schema(
    NestedField(1, "repo_full_name", StringType(), required=True),
    NestedField(2, "number", LongType(), required=True),
    NestedField(3, "state", StringType(), required=True),
    NestedField(4, "title", StringType()),
    NestedField(5, "user_login", StringType()),
    NestedField(6, "is_pull_request", BooleanType(), required=True),
    NestedField(7, "locked", BooleanType()),
    # List element IDs must be globally unique in the schema; using
    # sequential ids right after the parent matches the Iceberg convention.
    NestedField(
        8,
        "labels",
        ListType(element_id=16, element_type=StringType(), element_required=False),
    ),
    NestedField(
        9,
        "assignees",
        ListType(element_id=17, element_type=StringType(), element_required=False),
    ),
    NestedField(10, "comments", IntegerType()),
    NestedField(11, "created_at", TimestamptzType()),
    NestedField(12, "updated_at", TimestamptzType()),
    NestedField(13, "closed_at", TimestamptzType()),
    NestedField(14, "fetched_at", TimestamptzType(), required=True),
    NestedField(15, "raw_payload", StringType()),
)

COMMIT_SCHEMA = Schema(
    NestedField(1, "repo_full_name", StringType(), required=True),
    NestedField(2, "sha", StringType(), required=True),
    NestedField(3, "message", StringType()),
    NestedField(4, "author_login", StringType()),
    NestedField(5, "author_email", StringType()),
    NestedField(6, "authored_date", TimestamptzType()),
    NestedField(7, "committer_login", StringType()),
    NestedField(8, "committer_email", StringType()),
    NestedField(9, "committed_date", TimestamptzType()),
    NestedField(
        10,
        "parents",
        ListType(element_id=13, element_type=StringType(), element_required=False),
    ),
    NestedField(11, "fetched_at", TimestamptzType(), required=True),
    NestedField(12, "raw_payload", StringType()),
)

SCHEMAS: dict[str, Schema] = {
    "repo_metadata": REPO_METADATA_SCHEMA,
    "issue_or_pr": ISSUE_OR_PR_SCHEMA,
    "commit": COMMIT_SCHEMA,
}


class IcebergBronzeWriter:
    """PyIceberg-backed Bronze writer.

    One instance per ingest run. Calls `ensure_bucket()` (idempotent namespace
    + table creation), then `write(event_type, repo, records)` for each batch.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._catalog = RestCatalog(
            "de_lab",
            **{
                "uri": settings.lakekeeper_catalog_url,
                "warehouse": settings.lakekeeper_warehouse,
                "s3.access-key-id": settings.garage_s3_access_key.get_secret_value(),
                "s3.secret-access-key": settings.garage_s3_secret_key.get_secret_value(),
                "s3.path-style-access": "true",
                "s3.region": settings.garage_s3_region,
            },
        )
        self._namespace = (settings.iceberg_namespace,)
        self._table_cache: dict[str, object] = {}

    # ------------------------------------------------------------------
    # Public API — kept method-name-compatible with BronzeWriter so the
    # CLI can swap them via a config flag.
    # ------------------------------------------------------------------
    def ensure_bucket(self) -> None:
        """Idempotently create the namespace and all three tables."""
        try:
            self._catalog.create_namespace(self._namespace)
            log.info("namespace_created", namespace=self._namespace[0])
        except NamespaceAlreadyExistsError:
            log.debug("namespace_exists", namespace=self._namespace[0])

        for event_type, schema in SCHEMAS.items():
            table_id = f"{self._namespace[0]}.{event_type}"
            try:
                self._catalog.load_table(table_id)
                log.debug("table_exists", table=table_id)
            except NoSuchTableError:
                self._catalog.create_table(table_id, schema=schema)
                log.info("table_created", table=table_id)

    def write(
        self,
        event_type: str,
        repo_full_name: str,
        records: Iterable[BaseModel],
        partition_date: object | None = None,  # ignored; Iceberg snapshots time-track natively
    ) -> int:
        """Append records to the corresponding Iceberg table. Returns row count."""
        rows = [_to_arrow_row(r) for r in records]
        if not rows:
            log.info("write_skipped_empty", event_type=event_type, repo=repo_full_name)
            return 0

        schema = SCHEMAS[event_type]
        table_id = f"{self._namespace[0]}.{event_type}"
        table = self._table_cache.get(table_id) or self._catalog.load_table(table_id)
        self._table_cache[table_id] = table

        arrow_schema = schema.as_arrow()
        # `from_pylist` honors the explicit arrow schema, dodging the Phase 1
        # type-drift bug where pyarrow inferred per-batch types from samples.
        arrow_table = pa.Table.from_pylist(rows, schema=arrow_schema)
        table.append(arrow_table)

        snap = table.current_snapshot()
        log.info(
            "write_ok",
            event_type=event_type,
            repo=repo_full_name,
            rows=len(rows),
            table=table_id,
            snapshot_id=snap.snapshot_id if snap else None,
        )
        return len(rows)


def _to_arrow_row(model: BaseModel) -> dict[str, object]:
    """Convert a Pydantic model to a dict ready for Arrow conversion.

    `mode='python'` keeps native types (datetime, list, etc.) so Arrow's
    schema-aware converter can map them directly to timestamp/list columns.
    `mode='json'` would coerce datetimes to ISO strings, which Arrow then
    refuses to cast into TimestamptzType.

    `raw_payload` is JSON-serialized so the column lands as STRING regardless
    of the original dict shape.
    """
    row = model.model_dump(mode="python")
    payload = row.get("raw_payload")
    if payload is not None and not isinstance(payload, str):
        row["raw_payload"] = json.dumps(payload, ensure_ascii=False, default=str)
    return row
