#!/usr/bin/env bash
# Create the 1Password item used by `op run --env-file=.env`.
# Re-runnable: errors out if the item already exists.
#
# Usage:
#   make op-create
#   # or directly:
#   bash scripts/op-create-item.sh

set -euo pipefail

VAULT="${OP_VAULT:-Personal}"
ITEM="${OP_ITEM:-de-fullstack-demo}"

color() { printf "\033[%sm%s\033[0m" "$1" "$2"; }
info() { echo "$(color 36 "[op-create]") $*"; }
err()  { echo "$(color 31 "[op-create]") $*" >&2; }

command -v op > /dev/null || { err "1Password CLI 'op' not installed. brew install --cask 1password-cli"; exit 1; }
op account list > /dev/null 2>&1 || { err "Run: op signin"; exit 1; }

if op item get "$ITEM" --vault "$VAULT" > /dev/null 2>&1; then
  err "Item '$ITEM' already exists in vault '$VAULT'. Edit it via the 1Password UI instead."
  exit 1
fi

# ----------------------------------------------------------------------
# Prompt for the only value the user MUST provide
# ----------------------------------------------------------------------
if [ -z "${GITHUB_TOKEN_VALUE:-}" ]; then
  read -rsp "GitHub Fine-grained PAT (public_repo read): " GITHUB_TOKEN_VALUE
  echo
fi
if [ -z "$GITHUB_TOKEN_VALUE" ]; then
  err "GITHUB_TOKEN cannot be empty."
  exit 1
fi

GITHUB_TARGETS_DEFAULT="anthropics/claude-code,dbt-labs/dbt-core,apache/iceberg,duckdb/duckdb,temporalio/temporal"
read -rp "GITHUB_TARGET_REPOS [$GITHUB_TARGETS_DEFAULT]: " GITHUB_TARGETS_VALUE
GITHUB_TARGETS_VALUE="${GITHUB_TARGETS_VALUE:-$GITHUB_TARGETS_DEFAULT}"

# Auto-generate the rest
GARAGE_S3_ACCESS_KEY_VALUE="$(openssl rand -hex 16)"
GARAGE_S3_SECRET_KEY_VALUE="$(openssl rand -hex 32)"
GARAGE_RPC_SECRET_VALUE="$(openssl rand -hex 32)"
GARAGE_ADMIN_TOKEN_VALUE="$(openssl rand -hex 32)"
POSTGRES_PASSWORD_VALUE="$(openssl rand -hex 16)"

info "Creating 1Password item '$ITEM' in vault '$VAULT'..."

op item create \
  --category="API Credential" \
  --title="$ITEM" \
  --vault="$VAULT" \
  --tags="de-fullstack-demo" \
  "GITHUB_TOKEN[password]=$GITHUB_TOKEN_VALUE" \
  "GITHUB_TARGET_REPOS=$GITHUB_TARGETS_VALUE" \
  "GARAGE_S3_ACCESS_KEY=$GARAGE_S3_ACCESS_KEY_VALUE" \
  "GARAGE_S3_SECRET_KEY[password]=$GARAGE_S3_SECRET_KEY_VALUE" \
  "GARAGE_RPC_SECRET[password]=$GARAGE_RPC_SECRET_VALUE" \
  "GARAGE_ADMIN_TOKEN[password]=$GARAGE_ADMIN_TOKEN_VALUE" \
  "POSTGRES_PASSWORD[password]=$POSTGRES_PASSWORD_VALUE" \
  "LOCALSTACK_AUTH_TOKEN[password]= " \
  > /dev/null

info "Done. Verify with: op item get $ITEM --vault $VAULT"
info "Test injection:    op run --env-file=.env -- env | grep GITHUB_TOKEN"
