let JobSpec = ../../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = ".*",
  path = "Unit",
  name = "Unit-Tests"
}
