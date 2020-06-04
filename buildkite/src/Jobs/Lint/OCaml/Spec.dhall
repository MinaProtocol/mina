let JobSpec = ../../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = "^buildkite/src/Jobs/Lint/OCaml|^src/",
  path = "Lint",
  name = "OCaml"
}
