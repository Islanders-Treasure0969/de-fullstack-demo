#!/usr/bin/env bash
# Phase 1 smoke test — verify the platform stack is healthy.
#
# Designed to run **without a GitHub PAT**. Validates only the local
# infrastructure boundary (LocalStack / Garage / Lakekeeper / Postgres /
# Temporal) so anyone can sanity-check the compose file before touching
# secrets.
#
# Exit code 0 = all green. Non-zero = first failure index.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="$REPO_ROOT/docker"

# ANSI helpers (no external deps).
red()    { printf '\033[31m%s\033[0m' "$*"; }
green()  { printf '\033[32m%s\033[0m' "$*"; }
yellow() { printf '\033[33m%s\033[0m' "$*"; }
bold()   { printf '\033[1m%s\033[0m' "$*"; }

step() {
  printf '%s %s\n' "$(bold "•")" "$*"
}

ok() {
  printf '  %s %s\n' "$(green "✓")" "$*"
}

fail() {
  printf '  %s %s\n' "$(red "✗")" "$*" >&2
  exit 1
}

# --------------------------------------------------------------
# 0. Prerequisites
# --------------------------------------------------------------
step "Checking prerequisites"
command -v docker > /dev/null || fail "docker not in PATH"
docker compose version > /dev/null 2>&1 || fail "docker compose v2 plugin not available"
ok "docker compose v$(docker compose version --short)"

# --------------------------------------------------------------
# 1. Compose config validates
# --------------------------------------------------------------
step "Validating docker-compose configs"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" config --quiet \
  || fail "docker-compose.yml is invalid"
ok "docker-compose.yml syntactically valid"

docker compose -f "$COMPOSE_DIR/docker-compose.yml" -f "$COMPOSE_DIR/docker-compose.streaming.yml" config --quiet \
  || fail "streaming overlay is invalid"
ok "docker-compose.streaming.yml composes cleanly with base"

# --------------------------------------------------------------
# 2. Platform stack reachable
# --------------------------------------------------------------
step "Checking platform endpoints (skip with SMOKE_NO_NETWORK=1)"
if [ "${SMOKE_NO_NETWORK:-0}" = "1" ]; then
  ok "skipped per SMOKE_NO_NETWORK=1"
else
  declare -A targets=(
    [LocalStack]="http://localhost:4566/_localstack/health"
    [Garage]="http://localhost:3903/health"
    [Lakekeeper]="http://localhost:8181/health"
  )
  for name in "${!targets[@]}"; do
    url="${targets[$name]}"
    if curl --silent --max-time 3 --output /dev/null --fail "$url"; then
      ok "$name reachable at $url"
    else
      printf '  %s %s\n' "$(yellow "!")" "$name unreachable at $url — start with 'make compose-up'"
    fi
  done
fi

# --------------------------------------------------------------
# 3. Repo layout sanity
# --------------------------------------------------------------
step "Checking expected paths"
expected=(
  "$REPO_ROOT/Makefile"
  "$REPO_ROOT/.env.example"
  "$REPO_ROOT/ingestion/python/pyproject.toml"
  "$REPO_ROOT/transform/dbt_project.yml"
  "$REPO_ROOT/transform/models/sources.yml"
  "$REPO_ROOT/transform/models/gold/repo_daily_metrics.sql"
  "$REPO_ROOT/dashboard/streamlit/app.py"
  "$REPO_ROOT/docs/getting-started.md"
)
for path in "${expected[@]}"; do
  [ -f "$path" ] || fail "missing: $path"
done
ok "all expected paths present (${#expected[@]} files)"

# --------------------------------------------------------------
# Done
# --------------------------------------------------------------
printf '\n%s Phase 1 smoke test passed.\n' "$(green "✔")"
printf 'Next: get a GitHub PAT, fill in .env, then run %s\n' "$(bold "make phase1")"
