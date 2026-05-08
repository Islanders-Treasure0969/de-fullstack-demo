# Root terragrunt config — provides backend, provider, and shared inputs to all live/<env>/<component> stacks.

locals {
  # All env-level config is loaded from live/<env>/env.hcl
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

# ----------------------------------------------------------------
# Remote state (local backend for Phase 0; switch to S3/Garage in Phase 1)
# ----------------------------------------------------------------
remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}

# ----------------------------------------------------------------
# Default OpenTofu version constraint
# ----------------------------------------------------------------
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.8.0, < 2.0.0"
    }
  EOF
}

inputs = local.env_vars.locals
