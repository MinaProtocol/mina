let Select = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall 

let opamDirtyWhen = [
    Select.exactly "src/opam" "export",
    Select.exactly "scripts/setup-opam" "sh",
    Select.strictly (Select.contains "Makefile")
]
in

JobSpec::{
    dirtyWhen = opamDirtyWhen # [
        Select.strictlyStart (Select.contains "buildkite/src/Jobs/CompareTestSignatures"),
        Select.strictlyStart (Select.contains "src")
    ],
    name = "CompareTestSignatures"
}