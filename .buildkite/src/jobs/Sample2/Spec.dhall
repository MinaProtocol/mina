let JobSpec = ../../Lib/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = "^src/lib",
  name = "Sample2"
}
