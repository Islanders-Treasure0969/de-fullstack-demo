# Layer 00: Foundation (identity, base config). Lowest change frequency.
include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}
# Phase 1+ will populate.
