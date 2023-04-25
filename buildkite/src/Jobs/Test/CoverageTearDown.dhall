let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let CoverageTearDown = ../../Command/CoverageTearDown.dhall

let dependsOn =  [
    { name = "RosettaUnitTest", key = "rosetta-unit-test-dev" },
    { name = "ArchiveNodeUnitTest", key = "archive-unit-tests" },
    { name = "DaemonUnitTest", key = "unit-test-dev" },
    { name = "DelegationBackendUnitTest", key = "delegation-backend-unit-tests" },
    { name = "FuzzyZkappTest", key = "fuzzy-zkapp-unit-test-dev" },
    { name = "SnarkyJSTest", key = "snarkyjs-bindings-test" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
        S.strictlyStart (S.contains "src"),
        S.strictlyStart (S.contains "dockerfiles"),
        S.strictlyStart (S.contains "buildkite")
    ],
    path = "Test",
    name = "CoverageTearDown"
  },
  steps = [
    CoverageTearDown.execute dependsOn
  ]
}
