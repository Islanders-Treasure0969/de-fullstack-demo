# `_envcommon`

Component-level shared inputs that span environments.

`live/<env>/<component>/terragrunt.hcl` will `include` from here once Phase 1+ adds real components, e.g.:

```hcl
include "envcommon" {
  path = find_in_parent_folders("_envcommon/postgres.hcl")
}
```

This keeps env-specific overrides (endpoints, sizes) in `env.hcl` and component defaults here.
