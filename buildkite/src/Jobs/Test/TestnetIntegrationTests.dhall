let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let dependsOn = [
    { name = "TestnetIntegrationTests", key = "build-test-executive" },
    { name = "MinaArtifactBuster", key = "daemon-devnet-buster-docker-image" },
    { name = "MinaArtifactBuster", key = "archive-buster-docker-image" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
        S.strictlyStart (S.contains "src"),
        S.strictlyStart (S.contains "dockerfiles"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Test/TestnetIntegrationTest")
    ],
    path = "Test",
    name = "TestnetIntegrationTests"
  },
  steps = [
    TestExecutive.build "integration_tests",
    TestExecutive.execute "peers-reliability" dependsOn,
    TestExecutive.execute "chain-reliability" dependsOn,
    TestExecutive.execute "payment" dependsOn,
    TestExecutive.execute "delegation" dependsOn,
    TestExecutive.execute "gossip-consis" dependsOn,
    TestExecutive.execute "archive-node" dependsOn,
    TestExecutive.execute "snapps" dependsOn
  ]
}
