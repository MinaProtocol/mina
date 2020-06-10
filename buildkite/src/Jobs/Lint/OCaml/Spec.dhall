let S = ../../../Lib/SelectFiles.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall

let dirtyDhallDir = S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/OCaml")
let dirtyDhallDirCompiles = assert : S.compile [dirtyDhallDir] === "^buildkite/src/Jobs/Lint/OCaml"

in

JobSpec::{
  dirtyWhen = [
    dirtyDhallDir,
    S.strictlyStart (S.contains "src/")
  ],
  path = "Lint",
  name = "OCaml"
}

