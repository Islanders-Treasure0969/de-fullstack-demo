# Layer 05: Application-tier resources (GitHub repo settings, deploy secrets).
# Highest change frequency.
include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}
# Phase 1 will start populating with branch protection migration from _bootstrap.
