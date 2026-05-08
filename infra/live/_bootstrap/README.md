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

## Phase 0

This directory is a **placeholder** for now. Actual resource definitions land in Phase 1.
