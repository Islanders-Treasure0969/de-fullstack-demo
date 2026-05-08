# Layer 04: Operational mart (Postgres roles, schemas, grants for reverse-ETL targets).
include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}
# Phase 5 will populate.
