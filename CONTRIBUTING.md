# Contributing

> **This is a personal learning project and is not currently accepting external contributions.**
> The repository's `pull_request_creation_policy` is set to `collaborators_only`, so PRs from forks cannot be created. The code is published publicly for transparency and as a portfolio reference — feel free to fork and adapt for your own use.
>
> Issues are open for **questions or bug reports**, but not for feature requests at this time.
> Renovate and Dependabot bots manage dependency updates automatically.

The remainder of this document describes the contribution workflow used by the maintainer.

## Development setup

```bash
# Pre-commit hooks (gitleaks, formatters)
pip install pre-commit
pre-commit install

# Bring up the local platform stack
cd docker
docker compose up -d
```

## Pull requests

1. Branch from `main` using a descriptive name (`feat/...`, `fix/...`, `docs/...`).
2. Keep PRs focused — one concern per PR.
3. Run `pre-commit run --all-files` locally before pushing.
4. CI must pass: `ci`, `codeql`, `trivy`, `gitleaks`.
5. Renovate PRs auto-merge when CI passes (patch/minor only).

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(ingestion): add GitHub webhook receiver
fix(infra): correct Lakekeeper port mapping
docs(adr): record OpenTofu choice
```

## ADRs

When making a significant technical decision, add an ADR to [docs/adr/](docs/adr/).
Use the [MADR](https://adr.github.io/madr/) format.

## Code style

| Language | Formatter | Linter |
|----------|-----------|--------|
| Python | `ruff format` | `ruff check`, `mypy` |
| Go | `gofmt` | `golangci-lint` |
| Rust | `cargo fmt` | `cargo clippy` |
| TypeScript | `prettier` | `eslint`, `tsc --noEmit` |
| Terraform/OpenTofu | `tofu fmt` | `tflint`, `trivy config` |
| SQL (dbt) | `sqlfmt` | `sqlfluff` |
