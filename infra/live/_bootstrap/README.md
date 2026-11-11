# `_bootstrap`

**Manual `tofu apply` only** — runs once to create the artifacts that everything else depends on.

## What it provisions

- The state-bucket on Garage (or AWS S3 in prod) used by every other stack
- The GitHub repository's branch protection rules
- The CODEOWNERS-aware admin policy

## Why isn't this Terragrunt-managed?

It would be a chicken-and-egg problem: Terragrunt's remote-state config relies on a bucket that doesn't exist yet. So this layer uses plain OpenTofu with **local state** that you commit (encrypted) or recreate from scratch.

## Run

```bash
tofu init
tofu plan
tofu apply
```

## Operational notes

- `require_signed_commits = true` is enabled on `main`. **Do not switch the
  repo's merge strategy to "Rebase and merge"** — rebase replays each PR
  commit individually, so any unsigned commit in a PR will be rejected.
  Use "Squash and merge" or "Create a merge commit" so GitHub's web-flow
  key signs the resulting commit on the server side. Renovate and
  GitHub-API-driven flows are already signed and unaffected.

## Phase 0

This directory is a **placeholder** for now. Actual resource definitions land in Phase 1.
