# Layer 03: Warehouse (Lakekeeper Iceberg warehouses, namespaces).
include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}
# Phase 2 will populate.
