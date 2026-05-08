# dev environment shared inputs.
# Loaded by terragrunt.hcl at the root via `read_terragrunt_config(find_in_parent_folders("env.hcl"))`.

locals {
  env  = "dev"
  name = "de-lab"

  # ----------------------------------------------------------------
  # Local stack endpoints (LocalStack / Garage / Lakekeeper / Kafka)
  # ----------------------------------------------------------------
  aws_region          = "ap-northeast-1"
  aws_endpoint        = "http://localhost:4566"
  garage_s3_endpoint  = "http://localhost:3900"
  lakekeeper_endpoint = "http://localhost:8181"
  kafka_bootstrap     = "localhost:9092"
  postgres_host       = "localhost"
  postgres_port       = 5432

  # ----------------------------------------------------------------
  # Tags / labels propagated to all resources
  # ----------------------------------------------------------------
  default_tags = {
    project = "de-fullstack-demo"
    env     = "dev"
    owner   = "iwashita"
  }
}
