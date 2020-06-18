let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let JobSpec = ../../Pipeline/JobSpec.dhall

in

JobSpec::{
  dirtyWhen = [
    S.strictlyStart (S.contains "src/lib"),
    S.strictlyStart (S.contains "src/nonconsensus"),
    S.strictly (S.contains "Makefile"),
    S.strictlyStart (S.contains "buildkite/src/Jobs/Unit"),
    S.exactly "scripts/link-coredumps" "sh"
  ],
  name = "Unit"
}
