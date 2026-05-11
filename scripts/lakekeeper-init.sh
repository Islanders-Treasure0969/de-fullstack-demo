#!/usr/bin/env bash
# Bootstrap Lakekeeper and create the `de_lab` warehouse pointing at
# the Garage `iceberg-warehouse` bucket.
#
# Idempotent — safe to re-run.
#
# Required env (from `op run --env-file=.env`):
#   GARAGE_S3_ACCESS_KEY
#   GARAGE_S3_SECRET_KEY
#
# Usage:
#   make lakekeeper-init
#   bash scripts/lakekeeper-init.sh

set -euo pipefail

LK_HOST="${LAKEKEEPER_HOST:-http://localhost:8181}"

# S3 endpoint that works from BOTH the host (PyIceberg / DuckDB iceberg_scan)
# AND from inside the docker network (Lakekeeper container, dbt). The
# `garage` DNS only resolves inside the de-lab network, and `localhost`
# only works from the host, so we use the host's LAN IP — reachable from
# everywhere on dev's local Wi-Fi.
#
# Override with LAKEKEEPER_S3_ENDPOINT (e.g., add `garage 127.0.0.1` to
# /etc/hosts and set the env to http://garage:3900 for portability).
detect_lan_ip() {
  local ip
  ip=$(ipconfig getifaddr en0 2>/dev/null) || ip=""
  if [ -z "$ip" ]; then
    ip=$(ifconfig 2>/dev/null | awk '/inet 192\./ {print $2; exit}') || ip=""
  fi
  echo "$ip"
}
LK_INTERNAL_S3="${LAKEKEEPER_S3_ENDPOINT:-http://$(detect_lan_ip):3900}"
[[ "$LK_INTERNAL_S3" =~ ^http://:3900$ ]] && {
  err "Could not detect LAN IP. Set LAKEKEEPER_S3_ENDPOINT explicitly."
  exit 1
}

WAREHOUSE="${LAKEKEEPER_WAREHOUSE:-de_lab}"
WAREHOUSE_BUCKET="${LAKEKEEPER_WAREHOUSE_BUCKET:-iceberg-warehouse}"
WAREHOUSE_KEY_PREFIX="${LAKEKEEPER_WAREHOUSE_KEY_PREFIX:-warehouse}"
DEFAULT_PROJECT_ID="00000000-0000-0000-0000-000000000000"

color() { printf "\033[%sm%s\033[0m" "$1" "$2"; }
info()  { echo "$(color 36 "[lakekeeper-init]") $*"; }
warn()  { echo "$(color 33 "[lakekeeper-init]") $*" >&2; }
err()   { echo "$(color 31 "[lakekeeper-init]") $*" >&2; }

[ -n "${GARAGE_S3_ACCESS_KEY:-}" ] || { err "GARAGE_S3_ACCESS_KEY missing — run via op run"; exit 1; }
[ -n "${GARAGE_S3_SECRET_KEY:-}" ] || { err "GARAGE_S3_SECRET_KEY missing"; exit 1; }
command -v jq > /dev/null || { err "jq not installed (brew install jq)"; exit 1; }

# ----------------------------------------------------------------------
# 0. Wait for Lakekeeper /health
# ----------------------------------------------------------------------
info "Waiting for Lakekeeper at $LK_HOST/health..."
for _ in $(seq 1 30); do
  if curl -sf "$LK_HOST/health" > /dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -sf "$LK_HOST/health" > /dev/null 2>&1 || { err "Lakekeeper did not respond within 30s"; exit 1; }

# ----------------------------------------------------------------------
# 1. Server bootstrap (idempotent — /management/v1/info reports state)
# ----------------------------------------------------------------------
bootstrapped=$(curl -sf "$LK_HOST/management/v1/info" | jq -r '.bootstrapped // false')
if [ "$bootstrapped" = "true" ]; then
  info "Server already bootstrapped — skipping."
else
  info "Bootstrapping server (accepting terms of use)..."
  curl -sf -X POST "$LK_HOST/management/v1/bootstrap" \
    -H 'Content-Type: application/json' \
    -d '{"accept-terms-of-use": true}' > /dev/null
  info "Server bootstrapped."
fi

# ----------------------------------------------------------------------
# 2. Warehouse (idempotent — list + check)
# ----------------------------------------------------------------------
existing=$(curl -sf "$LK_HOST/management/v1/warehouse" \
  -H "x-project-id: $DEFAULT_PROJECT_ID" 2>/dev/null \
  | jq -r --arg name "$WAREHOUSE" '.warehouses[] | select(.name == $name) | .id' \
  || true)

if [ -n "$existing" ]; then
  info "Warehouse '$WAREHOUSE' already exists (id: $existing) — skipping creation."
else
  info "Creating warehouse '$WAREHOUSE' on bucket '$WAREHOUSE_BUCKET'..."
  body=$(jq -n \
    --arg name "$WAREHOUSE" \
    --arg bucket "$WAREHOUSE_BUCKET" \
    --arg prefix "$WAREHOUSE_KEY_PREFIX" \
    --arg endpoint "$LK_INTERNAL_S3" \
    --arg ak "$GARAGE_S3_ACCESS_KEY" \
    --arg sk "$GARAGE_S3_SECRET_KEY" \
    '{
      "warehouse-name": $name,
      "project-id": "00000000-0000-0000-0000-000000000000",
      "storage-profile": {
        "type": "s3",
        "bucket": $bucket,
        "key-prefix": $prefix,
        "endpoint": $endpoint,
        "region": "garage",
        "path-style-access": true,
        "flavor": "s3-compat",
        "sts-enabled": false
      },
      "storage-credential": {
        "type": "s3",
        "credential-type": "access-key",
        "aws-access-key-id": $ak,
        "aws-secret-access-key": $sk
      }
    }')
  http_code=$(curl -s -o /tmp/lk-warehouse-create.out -w "%{http_code}" \
    -X POST "$LK_HOST/management/v1/warehouse" \
    -H 'Content-Type: application/json' \
    -H "x-project-id: $DEFAULT_PROJECT_ID" \
    --data "$body")
  if [[ "$http_code" =~ ^2 ]]; then
    info "Warehouse created."
    cat /tmp/lk-warehouse-create.out | jq -r '. | "  id: \(.["warehouse-id"] // .id)"' 2>/dev/null || true
  else
    err "Warehouse create failed (HTTP $http_code):"
    cat /tmp/lk-warehouse-create.out >&2
    exit 1
  fi
fi

# ----------------------------------------------------------------------
# 3. Verify
# ----------------------------------------------------------------------
info "Verification:"
curl -sf "$LK_HOST/management/v1/warehouse" \
  -H "x-project-id: $DEFAULT_PROJECT_ID" \
  | jq -r '.warehouses[] | "  - \(.name) (id: \(.id), status: \(.status // "active"))"'

echo ""
echo "$(color 32 "[lakekeeper-init] Done.")"
echo "  Warehouse        : $WAREHOUSE"
echo "  Bucket / prefix  : $WAREHOUSE_BUCKET / $WAREHOUSE_KEY_PREFIX"
echo "  Iceberg endpoint : $LK_HOST/catalog"
