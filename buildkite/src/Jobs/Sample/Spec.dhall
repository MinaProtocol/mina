let JobSpec = ../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = "transition",
  name = "Sample"
}
