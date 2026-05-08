#!/usr/bin/env bash
# Bootstrap the local platform stack from a fresh clone.
# Idempotent — safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# 1. Copy .env.example to .env if missing
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from template — fill in secrets, then re-run."
  exit 0
fi

# 2. Generate Garage secrets if not yet set
if grep -q '^GARAGE_RPC_SECRET=$' .env; then
  rpc_secret="$(openssl rand -hex 32)"
  admin_token="$(openssl rand -hex 32)"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^GARAGE_RPC_SECRET=$|GARAGE_RPC_SECRET=${rpc_secret}|" .env
    sed -i '' "s|^GARAGE_ADMIN_TOKEN=$|GARAGE_ADMIN_TOKEN=${admin_token}|" .env
  else
    sed -i "s|^GARAGE_RPC_SECRET=$|GARAGE_RPC_SECRET=${rpc_secret}|" .env
    sed -i "s|^GARAGE_ADMIN_TOKEN=$|GARAGE_ADMIN_TOKEN=${admin_token}|" .env
  fi
  echo "Generated Garage secrets in .env"
fi

# 3. Install pre-commit hooks
if command -v pre-commit > /dev/null; then
  pre-commit install
else
  echo "WARN: pre-commit not installed. pip install pre-commit && pre-commit install"
fi

# 4. Bring up the platform
cd docker
docker compose up -d

echo ""
echo "Platform booting. Check health: docker compose ps"
echo "Tail logs:                   docker compose logs -f"
