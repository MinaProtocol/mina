let S = ../../../Lib/SelectFiles.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall
let ValidationService = ../../../Projects/ValidationService.dhall

let dirtyDhallDir = S.strictlyStart (S.contains "buildkite/src/Jobs/Test/ValidationService")

in JobSpec::{
  dirtyWhen = [
    dirtyDhallDir,
    S.strictlyStart (S.contains ValidationService.rootPath)
  ],
  path = "Test",
  name = "ValidationService"
}
