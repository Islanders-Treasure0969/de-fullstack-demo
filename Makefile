# de-fullstack-demo — convenience targets for Phase 1+ development.
# Cheat sheet: `make help` lists everything.
#
# Secrets are managed via 1Password CLI (`op run --env-file=.env`).
# Override the wrapper:
#   make ingest                 # uses op run automatically when op is installed
#   make ingest ENV_RUNNER=     # bypass op (when .env.local has plaintext)
# See ADR-0008 and docs/getting-started.md.

.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(shell git rev-parse --show-toplevel)

# ---- defaults overridable via env ----
PY ?= python3.12
ENV_FILE ?= $(REPO_ROOT)/.env
ENV_LOCAL ?= $(REPO_ROOT)/.env.local
DUCKDB_PATH ?= $(REPO_ROOT)/docker/data/de_lab.duckdb

# ----------------------------------------------------------------------
# Secret-injection wrapper
# ----------------------------------------------------------------------
# Resolution order:
#   1. ENV_RUNNER explicitly set (any value, including empty) → respected
#   2. .env.local exists                                       → use dotenv-style export
#   3. `op` on PATH + .env present                             → `op run --env-file=...`
#   4. fallback                                                → empty (callers must `set -a` themselves)
#
# Implementation: store the resolved command in OP_RUN.
# `make` evaluates this at parse time, so installing/removing op needs `make` re-invocation.
ifndef ENV_RUNNER
  ifneq ("$(wildcard $(ENV_LOCAL))","")
    OP_RUN := set -a && source $(ENV_LOCAL) && set +a &&
  else ifneq ("$(shell command -v op 2>/dev/null)","")
    OP_RUN := op run --env-file=$(ENV_FILE) --no-masking --
  else
    OP_RUN :=
  endif
else
  OP_RUN := $(ENV_RUNNER)
endif

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} \
	     /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ----------------------------------------------------------------------
# Bootstrap
# ----------------------------------------------------------------------
.PHONY: bootstrap
bootstrap: ## First-time setup (1Password item, pre-commit, compose up)
	@bash $(REPO_ROOT)/scripts/bootstrap.sh

.PHONY: env-check
env-check: ## Verify env wiring (1Password item or .env.local)
	@test -f $(ENV_FILE) || (echo "Missing $(ENV_FILE)" && exit 1)
	@if [ -f "$(ENV_LOCAL)" ]; then \
	  echo "env: using $(ENV_LOCAL)"; \
	elif command -v op >/dev/null; then \
	  op item get de-fullstack-demo --vault Personal --format json >/dev/null \
	    && echo "env: using op item 'de-fullstack-demo'" \
	    || (echo "1Password item 'de-fullstack-demo' missing — see docs/getting-started.md" && exit 1); \
	else \
	  echo "Neither $(ENV_LOCAL) nor 'op' CLI found. Install 1Password CLI or create .env.local." >&2; \
	  exit 1; \
	fi

# ----------------------------------------------------------------------
# Docker compose
# ----------------------------------------------------------------------
# `compose up` needs GARAGE_RPC_SECRET, GARAGE_ADMIN_TOKEN, POSTGRES_PASSWORD
# from the env (Garage refuses to start without a 32-byte rpc_secret).
# We wrap with $(OP_RUN) so 1Password (or .env.local) supplies them.
.PHONY: compose-up
compose-up: env-check ## Start the platform stack
	cd $(REPO_ROOT)/docker && $(OP_RUN) docker compose up -d

.PHONY: compose-up-streaming
compose-up-streaming: env-check ## Start the platform stack + Kafka
	cd $(REPO_ROOT)/docker && $(OP_RUN) docker compose -f docker-compose.yml -f docker-compose.streaming.yml up -d

.PHONY: compose-down
compose-down: ## Stop the platform stack
	cd $(REPO_ROOT)/docker && docker compose down

.PHONY: compose-ps
compose-ps: ## Show running containers
	cd $(REPO_ROOT)/docker && docker compose ps

.PHONY: compose-logs
compose-logs: ## Tail logs
	cd $(REPO_ROOT)/docker && docker compose logs -f

# ----------------------------------------------------------------------
# Garage cluster init (one-time per fresh stack)
# ----------------------------------------------------------------------
.PHONY: garage-init
garage-init: env-check ## Assign layout, create bucket, import keys, grant access
	$(OP_RUN) bash $(REPO_ROOT)/scripts/garage-init.sh

# ----------------------------------------------------------------------
# Python ingestion
# ----------------------------------------------------------------------
.PHONY: ingest-install
ingest-install: ## Install ingestor in dev mode
	cd $(REPO_ROOT)/ingestion/python && \
	  $(PY) -m venv .venv && \
	  .venv/bin/pip install -e ".[dev]"

.PHONY: ingest-bootstrap
ingest-bootstrap: env-check ## Create the bronze bucket on Garage
	cd $(REPO_ROOT)/ingestion/python && \
	  $(OP_RUN) .venv/bin/de-lab-ingestor bootstrap

.PHONY: ingest
ingest: env-check ## Pull all configured target repos
	cd $(REPO_ROOT)/ingestion/python && \
	  $(OP_RUN) .venv/bin/de-lab-ingestor ingest

.PHONY: ingest-test
ingest-test: ## Run the ingestor unit tests (no secrets needed)
	cd $(REPO_ROOT)/ingestion/python && .venv/bin/pytest

# ----------------------------------------------------------------------
# dbt — uses its own venv at transform/.venv
# ----------------------------------------------------------------------
DBT_VENV := $(REPO_ROOT)/transform/.venv
DBT := $(DBT_VENV)/bin/dbt
DBT_PROFILES_DIR := $(REPO_ROOT)/transform

.PHONY: dbt-install
dbt-install: ## Create transform/.venv and install dbt-core + dbt-duckdb
	$(PY) -m venv $(DBT_VENV)
	$(DBT_VENV)/bin/pip install -r $(REPO_ROOT)/transform/requirements.txt
	@test -f $(DBT_PROFILES_DIR)/profiles.yml || cp $(REPO_ROOT)/transform/profiles.yml.example $(DBT_PROFILES_DIR)/profiles.yml
	@echo "dbt ready: $(DBT)"

.PHONY: dbt-deps
dbt-deps: ## Install dbt packages from packages.yml
	cd $(REPO_ROOT)/transform && DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) deps

.PHONY: dbt-build
dbt-build: env-check ## Run dbt build end-to-end
	cd $(REPO_ROOT)/transform && $(OP_RUN) bash -c 'DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) build'

.PHONY: dbt-debug
dbt-debug: env-check ## Validate dbt connection
	cd $(REPO_ROOT)/transform && $(OP_RUN) bash -c 'DBT_PROFILES_DIR=$(DBT_PROFILES_DIR) $(DBT) debug'

# ----------------------------------------------------------------------
# Streamlit
# ----------------------------------------------------------------------
.PHONY: dashboard
dashboard: ## Run the Streamlit dashboard (no secrets — reads local DuckDB)
	cd $(REPO_ROOT)/dashboard/streamlit && \
	  DUCKDB_PATH=$(DUCKDB_PATH) streamlit run app.py

# ----------------------------------------------------------------------
# Quality
# ----------------------------------------------------------------------
.PHONY: lint
lint: ## Run all linters
	cd $(REPO_ROOT)/ingestion/python && .venv/bin/ruff check .
	cd $(REPO_ROOT)/transform && command -v sqlfluff > /dev/null && sqlfluff lint models/ || true

.PHONY: format
format: ## Run all formatters
	cd $(REPO_ROOT)/ingestion/python && .venv/bin/ruff format .

.PHONY: precommit
precommit: ## Run all pre-commit hooks against everything
	pre-commit run --all-files

# ----------------------------------------------------------------------
# End-to-end
# ----------------------------------------------------------------------
.PHONY: phase1
phase1: compose-up garage-init ingest-install ingest-bootstrap ingest dbt-install dbt-deps dbt-build dashboard ## Run the full Phase 1 pipeline

# ----------------------------------------------------------------------
# 1Password helpers
# ----------------------------------------------------------------------
.PHONY: op-create
op-create: ## Create the de-fullstack-demo 1Password item (interactive)
	@bash $(REPO_ROOT)/scripts/op-create-item.sh

.PHONY: op-show
op-show: ## Print the resolved env (mask secrets)
	@command -v op >/dev/null || (echo "op CLI not installed" && exit 1)
	@op run --env-file=$(ENV_FILE) -- env | grep -E '^(GITHUB_|GARAGE_|POSTGRES_|LOCALSTACK_)' | sed -E 's/(=.{3}).*/\1***/'
