let JobSpec = ../../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = ".*",
  path = "Lint",
  name = "Fast"
}
