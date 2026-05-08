# Layer 02: Streaming (Kafka topics, Schema Registry subjects).
include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}
# Phase 3 will populate with topics: github.events.raw, github.events.parsed, etc.
