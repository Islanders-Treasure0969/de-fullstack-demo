# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, **please do not open a public issue**.
Instead, use one of these channels:

1. **GitHub Private Vulnerability Reporting** (preferred):
   <https://github.com/Islanders-Treasure0969/de-fullstack-demo/security/advisories/new>
2. Email the maintainer directly via the address in the GitHub profile.

You can expect:
- Acknowledgement within **72 hours**
- An initial assessment within **1 week**
- A coordinated fix and disclosure timeline communicated upfront

## Supported Versions

This project is a learning playground and does **not** ship as a versioned library.
The `main` branch is the only supported version. Security fixes are applied directly to `main`.

## Defense in Depth

This repository ships with the following automated security controls:

| Control | Tool | Trigger |
|---------|------|---------|
| Dependency updates (multi-language) | Renovate | continuous |
| Vulnerability alerts | GitHub Dependabot Alerts | continuous |
| SAST | CodeQL | PR + weekly |
| Container & IaC scan | Trivy | PR + nightly |
| Secret scan (live) | GitHub Secret Scanning | continuous |
| Secret scan (CI double-check) | gitleaks | PR |
| SBOM generation | Syft (CycloneDX) | release + nightly |
| Posture scoring | OpenSSF Scorecard | weekly |
| Critical alert auto-issue | custom workflow | every 6 hours |

## Auto-merge Policy

| Update type | Policy |
|-------------|--------|
| Security patches (any severity) | **Auto-merge after CI** |
| Patch / Minor (non-security) | Auto-merge after CI |
| Major | Manual review required (CODEOWNERS) |
| Lockfile maintenance | Weekly auto-merge |

Auto-merge requires all status checks (CI / CodeQL / Trivy) to pass.

## Secrets Hygiene

- `.env` files are git-ignored — only `.env.example` is committed.
- LocalStack uses dummy AWS credentials (`AKIAIOSFODNN7EXAMPLE`).
- pre-commit hooks block accidental secret commits via gitleaks.
- GitHub Secret Scanning is enabled at the org/repo level.
- **Never** commit real cloud credentials to this repo.
