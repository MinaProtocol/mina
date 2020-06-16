let S = ../../../Lib/SelectFiles.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall
let ValidationService = ../../../Projects/ValidationService.dhall

let dirtyDhallDir = S.strictlyStart (S.contains "buildkite/src/Jobs/Lint/ValidationService")

in JobSpec::{
  dirtyWhen = [
    dirtyDhallDir,
    S.strictlyStart (S.contains ValidationService.rootPath)
  ],
  path = "Lint",
  name = "ValidationService"
}
