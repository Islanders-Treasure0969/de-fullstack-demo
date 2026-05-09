#!/usr/bin/env bash
# Bootstrap the local platform stack from a fresh clone.
# Idempotent — safe to re-run.
#
# Secret strategy:
#   1. If `op` CLI is on PATH and the user is signed in, use 1Password.
#   2. Else fall back to .env.local (created from .env.example).
#
# See ADR-0008 for the rationale.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

color() { printf "\033[%sm%s\033[0m" "$1" "$2"; }
info() { echo "$(color 36 "[bootstrap]") $*"; }
warn() { echo "$(color 33 "[bootstrap]") $*" >&2; }
err()  { echo "$(color 31 "[bootstrap]") $*" >&2; }

# ----------------------------------------------------------------------
# 1. Choose secret backend
# ----------------------------------------------------------------------
secret_backend=""
if command -v op > /dev/null; then
  if op account list > /dev/null 2>&1; then
    secret_backend="1password"
    info "Detected 1Password CLI — using 'op run --env-file=.env'."
  else
    warn "op CLI installed but not signed in. Run: op signin"
    warn "Falling back to .env.local."
  fi
fi

if [ -z "$secret_backend" ]; then
  secret_backend="dotenv-local"
  if [ ! -f .env.local ]; then
    cp .env.example .env.local
    info "Created .env.local from .env.example — fill in real values."
  else
    info "Using existing .env.local"
  fi
fi

# ----------------------------------------------------------------------
# 2. 1Password item check
# ----------------------------------------------------------------------
if [ "$secret_backend" = "1password" ]; then
  if ! op item get de-fullstack-demo --vault Personal --format json > /dev/null 2>&1; then
    warn "1Password item 'de-fullstack-demo' not found."
    warn "Run: make op-create"
  else
    info "1Password item 'de-fullstack-demo' detected."
  fi
fi

# ----------------------------------------------------------------------
# 3. pre-commit hooks
# ----------------------------------------------------------------------
if command -v pre-commit > /dev/null; then
  pre-commit install --quiet
  info "pre-commit hooks installed."
else
  warn "pre-commit not installed. pip install pre-commit"
fi

# ----------------------------------------------------------------------
# 4. Bring up the platform
# ----------------------------------------------------------------------
info "Starting docker compose..."
(cd docker && docker compose up -d)

cat <<EOF

$(color 32 "[bootstrap] Done.")

  secret backend : $secret_backend
  next steps     :
    - make compose-ps   # check services healthy
    - make ingest-test  # run unit tests
    - make phase1       # full E2E pipeline (after secrets are set)

EOF
