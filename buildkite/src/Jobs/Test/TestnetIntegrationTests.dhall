let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let ExecuteIntegrationTest = ../../Command/ExecuteIntegrationTest.dhall

let dependsOn = [
    { name = "MinaArtifact", key = "mina-docker-image" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
        S.strictlyStart (S.contains "src"),
        S.strictlyStart (S.contains "src/app/test-executive"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Test/TestnetIntegrationTest")
    ],
    path = "Test",
    name = "TestnetIntegrationTests"
  },
  steps = [
    ExecuteIntegrationTest.step "block-production" dependsOn
  ]
}
