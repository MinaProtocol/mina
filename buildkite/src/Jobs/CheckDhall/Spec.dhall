let JobSpec = ../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = "^buildkite/(.*\\.dhall\\\$|Makefile\\\$|scripts/generate-jobs\\.sh\\\$)",
  name = "CheckDhall"
}
