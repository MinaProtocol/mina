let S = ../../../Lib/SelectFiles.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = [
    S.contains "^buildkite/src/Jobs/Lint/OCaml",
    S.contains "^src/"
  ],
  path = "Lint",
  name = "OCaml"
}
