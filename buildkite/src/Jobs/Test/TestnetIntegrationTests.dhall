let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let dependsOn = [
    { name = "TestnetIntegrationTests", key = "build-test-executive" },
    { name = "MinaArtifact", key = "mina-docker-image" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
        S.strictlyStart (S.contains "src"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Test/TestnetIntegrationTest")
    ],
    path = "Test",
    name = "TestnetIntegrationTests"
  },
  steps = [
    TestExecutive.build "testnet_postake_medium_curves",

    TestExecutive.execute "block-production" dependsOn,
    TestExecutive.execute "bootstrap" dependsOn,
    TestExecutive.execute "bp-timed-accts" dependsOn,
    TestExecutive.execute "peers" dependsOn,
    TestExecutive.execute "pmt-timed-accts" dependsOn,
    TestExecutive.execute "send-payment" dependsOn
  ]
}
