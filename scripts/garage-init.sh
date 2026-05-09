#!/usr/bin/env bash
# Initialize the single-node Garage cluster:
#   1. Assign role to the local node (zone, capacity)
#   2. Apply staged layout
#   3. Create the `bronze` bucket
#   4. Import the access keys from env (resolved by `op run`)
#   5. Grant the imported key read+write on `bronze`
#
# Idempotent — safe to re-run after a stack restart. Each step short-circuits
# if the desired state already exists.
#
# Required env (resolved via `op run --env-file=.env`):
#   GARAGE_S3_ACCESS_KEY
#   GARAGE_S3_SECRET_KEY
#
# Usage:
#   make garage-init        # via Makefile (wraps with op run automatically)
#   bash scripts/garage-init.sh  # if env vars are already exported

set -euo pipefail

CONTAINER="${GARAGE_CONTAINER:-de-lab-garage-1}"
ZONE="${GARAGE_ZONE:-dc1}"
CAPACITY="${GARAGE_CAPACITY:-10G}"
TAG="${GARAGE_TAG:-local}"
BUCKET="${GARAGE_BUCKET:-bronze}"
KEY_NAME="${GARAGE_KEY_NAME:-de-lab}"

color() { printf "\033[%sm%s\033[0m" "$1" "$2"; }
info()  { echo "$(color 36 "[garage-init]") $*"; }
warn()  { echo "$(color 33 "[garage-init]") $*" >&2; }
err()   { echo "$(color 31 "[garage-init]") $*" >&2; }

g() { docker exec -i "$CONTAINER" /garage "$@"; }

# ----------------------------------------------------------------------
# 0. Pre-flight
# ----------------------------------------------------------------------
docker inspect "$CONTAINER" > /dev/null 2>&1 || {
  err "Container '$CONTAINER' is not running. Run 'make compose-up' first."
  exit 1
}

[ -n "${GARAGE_S3_ACCESS_KEY:-}" ] || { err "GARAGE_S3_ACCESS_KEY missing — run via 'make garage-init' (op run)"; exit 1; }
[ -n "${GARAGE_S3_SECRET_KEY:-}" ] || { err "GARAGE_S3_SECRET_KEY missing — run via 'make garage-init' (op run)"; exit 1; }

# Wait for daemon to accept commands
info "Waiting for Garage daemon..."
for _ in $(seq 1 30); do
  if g status > /dev/null 2>&1; then
    break
  fi
  sleep 1
done
g status > /dev/null 2>&1 || { err "Garage daemon did not respond within 30s"; exit 1; }

# ----------------------------------------------------------------------
# 1. Layout: assign role + apply (idempotent)
# ----------------------------------------------------------------------
status_out=$(g status 2>&1)
node_id=$(echo "$status_out" | awk '/HEALTHY NODES/{flag=1; next} flag && NF && $1 != "ID" {print $1; exit}')
[ -n "$node_id" ] || { err "Could not parse node ID from 'garage status'"; echo "$status_out" >&2; exit 1; }

if echo "$status_out" | grep -q "NO ROLE ASSIGNED"; then
  info "Assigning role to node $node_id (zone=$ZONE, cap=$CAPACITY)..."
  g layout assign "$node_id" -z "$ZONE" -c "$CAPACITY" -t "$TAG"
  info "Applying staged layout (version 1)..."
  g layout apply --version 1
else
  info "Node $node_id already has role assigned — skipping layout."
fi

# ----------------------------------------------------------------------
# 2. Bucket (idempotent)
# ----------------------------------------------------------------------
if g bucket list 2>/dev/null | awk 'NR>2 {print $1}' | grep -qx "$BUCKET"; then
  info "Bucket '$BUCKET' already exists — skipping."
else
  info "Creating bucket '$BUCKET'..."
  g bucket create "$BUCKET"
fi

# ----------------------------------------------------------------------
# 3. Key import (idempotent)
# ----------------------------------------------------------------------
if g key list 2>/dev/null | awk 'NR>2 {print $2}' | grep -qx "$KEY_NAME"; then
  info "Key '$KEY_NAME' already exists — skipping import."
else
  info "Importing access keys (id from env, name=$KEY_NAME)..."
  g key import --yes -n "$KEY_NAME" "$GARAGE_S3_ACCESS_KEY" "$GARAGE_S3_SECRET_KEY"
fi

# ----------------------------------------------------------------------
# 4. Grant the key access to the bucket (idempotent: garage allow is OK to re-run)
# ----------------------------------------------------------------------
info "Granting read+write on '$BUCKET' to key '$KEY_NAME'..."
g bucket allow --read --write --owner "$BUCKET" --key "$KEY_NAME"

# ----------------------------------------------------------------------
# 5. Verify
# ----------------------------------------------------------------------
info "Verification:"
g bucket info "$BUCKET" 2>&1 | sed 's/^/  /'

echo ""
echo "$(color 32 "[garage-init] Done.")"
echo "  Bucket  : $BUCKET"
echo "  Key name: $KEY_NAME"
echo "  S3 endpoint (host): http://localhost:3900"
