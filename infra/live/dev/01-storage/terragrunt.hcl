# Layer 01: Object storage (Garage buckets, LocalStack S3 buckets)
# Lifecycle: changes when adding new data products.

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

# Phase 1+ will populate this with bucket definitions.
# Example (to enable later):
#
# terraform {
#   source = "../../../modules/garage-bucket"
# }
#
# inputs = {
#   buckets = ["bronze", "silver", "gold", "iceberg-warehouse"]
# }
