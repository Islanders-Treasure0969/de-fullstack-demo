terraform {
  required_version = ">= 1.8.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# GitHub branch protection for `main`.
# CODEOWNERS-required reviews + status checks gate every merge.
provider "github" {
  owner = var.github_owner
}

variable "github_owner" {
  type        = string
  description = "GitHub user or org that owns the repo"
  default     = "Islanders-Treasure0969"
}

variable "github_repo" {
  type        = string
  description = "Repository name"
  default     = "de-fullstack-demo"
}

resource "github_branch_protection" "main" {
  repository_id = var.github_repo
  pattern       = "main"

  required_status_checks {
    strict = true
    # Each workflow exposes a single aggregator job named `gate` so the
    # status-check contract here stays stable when individual jobs change.
    contexts = [
      "ci / gate",
      "codeql / gate",
      "trivy / gate",
      "gitleaks / gate",
    ]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
    require_code_owner_reviews      = true
    dismiss_stale_reviews           = true
  }

  allows_deletions        = false
  allows_force_pushes     = false
  enforce_admins          = false # let Renovate bypass via auto-merge
  required_linear_history = true
  require_signed_commits  = true
}
