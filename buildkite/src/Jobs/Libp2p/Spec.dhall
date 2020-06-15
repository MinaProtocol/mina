let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

in
JobSpec::{
  dirtyWhen = [
    S.strictly (S.contains "Makefile"),
    S.strictlyStart (S.contains "buildkite/src/Jobs/Libp2p"),
    S.strictlyStart (S.contains "src")
  ],
  name = "Libp2p"
}
