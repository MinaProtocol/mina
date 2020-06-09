let JobSpec = ../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = "^src/lib",
  name = "Sample2"
}
