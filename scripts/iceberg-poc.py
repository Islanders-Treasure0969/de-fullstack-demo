"""Phase 2A proof-of-concept — write a tiny Iceberg table via PyIceberg
into the Lakekeeper-managed warehouse, then read it back via the DuckDB
iceberg extension.

Confirms the full Iceberg path is wired:
    PyIceberg (write) ─▶ Lakekeeper REST catalog ─▶ Garage S3
                                     ▲
                                     └── DuckDB iceberg ATTACH (read)

Run:
    make iceberg-poc          # via Makefile (op run wraps with .env)

Required env (resolved by op run):
    GARAGE_S3_ACCESS_KEY
    GARAGE_S3_SECRET_KEY

Phase 2B will replace this PoC with a real ingestor migration:
PyIceberg writes from `ingestion/python/`, dbt bronze stg_* read via
DuckDB iceberg ATTACH instead of `read_parquet(...)`.
"""

from __future__ import annotations

import os
from datetime import UTC, datetime

import duckdb
import pyarrow as pa
from pyiceberg.catalog.rest import RestCatalog
from pyiceberg.exceptions import NoSuchTableError
from pyiceberg.schema import Schema
from pyiceberg.types import IntegerType, NestedField, StringType, TimestamptzType

# --------------------------------------------------------------
# Config (defaults match local docker-compose; override via env)
# --------------------------------------------------------------
LK_CATALOG = os.environ.get("LAKEKEEPER_CATALOG_URL", "http://localhost:8181/catalog")
WAREHOUSE = os.environ.get("LAKEKEEPER_WAREHOUSE", "de_lab")
S3_ENDPOINT = os.environ.get("ICEBERG_S3_ENDPOINT", "192.168.11.51:3900")
S3_REGION = os.environ.get("ICEBERG_S3_REGION", "garage")

NAMESPACE = ("github_oss",)
TABLE_ID = "github_oss.poc_repo_metadata"


def main() -> None:
    # --------------------------------------------------------------
    # 1. PyIceberg — write
    # --------------------------------------------------------------
    print("=== PyIceberg write ===")
    catalog = RestCatalog(
        "de_lab",
        **{
            "uri": LK_CATALOG,
            "warehouse": WAREHOUSE,
            "s3.access-key-id": os.environ["GARAGE_S3_ACCESS_KEY"],
            "s3.secret-access-key": os.environ["GARAGE_S3_SECRET_KEY"],
            "s3.path-style-access": "true",
            "s3.region": S3_REGION,
        },
    )

    if NAMESPACE not in list(catalog.list_namespaces()):
        catalog.create_namespace(NAMESPACE)
        print(f"  namespace {NAMESPACE} created")
    else:
        print(f"  namespace {NAMESPACE} already exists")

    schema = Schema(
        NestedField(
            field_id=1, name="repo_full_name", field_type=StringType(), required=True
        ),
        NestedField(
            field_id=2,
            name="stargazers_count",
            field_type=IntegerType(),
            required=False,
        ),
        NestedField(
            field_id=3, name="fetched_at", field_type=TimestamptzType(), required=True
        ),
    )

    try:
        table = catalog.load_table(TABLE_ID)
        print(f"  table {TABLE_ID} already exists ({len(table.snapshots())} snapshots)")
    except NoSuchTableError:
        table = catalog.create_table(TABLE_ID, schema=schema)
        print(f"  table {TABLE_ID} created")

    now = datetime.now(tz=UTC)
    data = pa.table(
        {
            "repo_full_name": [
                "anthropics/claude-code",
                "duckdb/duckdb",
                "apache/iceberg",
            ],
            "stargazers_count": [121960, 38025, 8836],
            "fetched_at": [now, now, now],
        },
        schema=table.schema().as_arrow(),
    )
    table.append(data)
    print(
        f"  appended {data.num_rows} rows; snapshot id = {table.current_snapshot().snapshot_id}"
    )

    # --------------------------------------------------------------
    # 2. DuckDB — read via iceberg ATTACH
    # --------------------------------------------------------------
    print("\n=== DuckDB iceberg ATTACH read ===")
    con = duckdb.connect(":memory:")
    con.sql("install iceberg; load iceberg;")
    con.sql("install httpfs; load httpfs;")
    con.sql(
        f"""
        SET s3_endpoint='{S3_ENDPOINT}';
        SET s3_region='{S3_REGION}';
        SET s3_access_key_id='{os.environ["GARAGE_S3_ACCESS_KEY"]}';
        SET s3_secret_access_key='{os.environ["GARAGE_S3_SECRET_KEY"]}';
        SET s3_use_ssl=false;
        SET s3_url_style='path';
        """
    )
    con.sql(
        f"""
        ATTACH 'de_lab' AS lakekeeper (
            TYPE ICEBERG,
            ENDPOINT '{LK_CATALOG}',
            AUTHORIZATION_TYPE 'none'
        );
        """
    )

    rows = con.sql(
        "SELECT repo_full_name, stargazers_count, fetched_at "
        "FROM lakekeeper.github_oss.poc_repo_metadata "
        "ORDER BY stargazers_count DESC"
    ).fetchall()
    for r in rows:
        print(f"  {r}")

    print(f"\nlocation: {table.location()}")
    print("\n=== PoC OK ===")


if __name__ == "__main__":
    main()
