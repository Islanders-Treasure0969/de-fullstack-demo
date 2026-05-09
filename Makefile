# de-fullstack-demo — convenience targets for Phase 1+ development.
# Cheat sheet: `make help` lists everything.

.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(shell git rev-parse --show-toplevel)

# ---- defaults overridable via env ----
PY ?= python3.12
ENV_FILE ?= $(REPO_ROOT)/.env
DUCKDB_PATH ?= $(REPO_ROOT)/docker/data/de_lab.duckdb

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} \
	     /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ----------------------------------------------------------------------
# Bootstrap
# ----------------------------------------------------------------------
.PHONY: bootstrap
bootstrap: ## First-time setup (env, secrets, pre-commit, compose up)
	@bash $(REPO_ROOT)/scripts/bootstrap.sh

.PHONY: env-check
env-check: ## Verify required env vars are set in .env
	@test -f $(ENV_FILE) || (echo "Missing $(ENV_FILE) — run 'make bootstrap'." && exit 1)
	@grep -E '^GITHUB_TOKEN=.+' $(ENV_FILE) > /dev/null || (echo "GITHUB_TOKEN is empty in .env" && exit 1)
	@grep -E '^GITHUB_TARGET_REPOS=.+' $(ENV_FILE) > /dev/null || (echo "GITHUB_TARGET_REPOS is empty in .env" && exit 1)
	@echo "env OK"

# ----------------------------------------------------------------------
# Docker compose
# ----------------------------------------------------------------------
.PHONY: compose-up
compose-up: ## Start the platform stack (LocalStack/Garage/Lakekeeper/Postgres/Temporal)
	cd $(REPO_ROOT)/docker && docker compose up -d

.PHONY: compose-up-streaming
compose-up-streaming: ## Start the platform stack + Kafka
	cd $(REPO_ROOT)/docker && docker compose -f docker-compose.yml -f docker-compose.streaming.yml up -d

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
# Python ingestion
# ----------------------------------------------------------------------
.PHONY: ingest-install
ingest-install: ## Install ingestor in dev mode
	cd $(REPO_ROOT)/ingestion/python && \
	  $(PY) -m venv .venv && \
	  .venv/bin/pip install -e ".[dev]"

.PHONY: ingest-bootstrap
ingest-bootstrap: env-check ## Create the bronze bucket on Garage
	cd $(REPO_ROOT)/ingestion/python && .venv/bin/de-lab-ingestor bootstrap

.PHONY: ingest
ingest: env-check ## Pull all configured target repos
	cd $(REPO_ROOT)/ingestion/python && .venv/bin/de-lab-ingestor ingest

.PHONY: ingest-test
ingest-test: ## Run the ingestor unit tests
	cd $(REPO_ROOT)/ingestion/python && .venv/bin/pytest

# ----------------------------------------------------------------------
# dbt
# ----------------------------------------------------------------------
.PHONY: dbt-deps
dbt-deps: ## Install dbt packages (dbt_utils etc.)
	cd $(REPO_ROOT)/transform && dbt deps

.PHONY: dbt-build
dbt-build: ## Run dbt build (run + test) end-to-end
	cd $(REPO_ROOT)/transform && dbt build

.PHONY: dbt-debug
dbt-debug: ## Validate dbt connection
	cd $(REPO_ROOT)/transform && dbt debug

# ----------------------------------------------------------------------
# Streamlit
# ----------------------------------------------------------------------
.PHONY: dashboard
dashboard: ## Run the Streamlit dashboard
	cd $(REPO_ROOT)/dashboard/streamlit && \
	  DUCKDB_PATH=$(DUCKDB_PATH) streamlit run app.py

# ----------------------------------------------------------------------
# Smoke test (no PAT required)
# ----------------------------------------------------------------------
.PHONY: smoke
smoke: ## Sanity-check compose configs + platform health (no GitHub PAT needed)
	@bash $(REPO_ROOT)/scripts/smoke-test.sh

.PHONY: smoke-offline
smoke-offline: ## Smoke test without hitting compose services (CI-safe)
	@SMOKE_NO_NETWORK=1 bash $(REPO_ROOT)/scripts/smoke-test.sh

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
phase1: compose-up ingest-bootstrap ingest dbt-deps dbt-build dashboard ## Run the full Phase 1 pipeline
