let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let opamDirtyWhen = [
    S.exactly "src/opam" "export",
    S.exactly "scripts/setup-opam" "sh",
    S.strictly (S.contains "Makefile"),
    S.exactly "buildkite/src/Command/OpamInit" "dhall",
    S.exactly "buildkite/scripts/cache-through" "sh"
  ]

in
JobSpec::{
  dirtyWhen = opamDirtyWhen # [
    S.strictlyStart (S.contains "buildkite/src/Jobs/ClientSdk"),
    S.strictlyStart (S.contains "src")
  ],
  name = "ClientSdk"
}
