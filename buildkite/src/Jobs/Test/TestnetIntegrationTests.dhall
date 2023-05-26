let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let TestExecutive = ../../Command/TestExecutive.dhall

let dependsOn = [
    { name = "TestnetIntegrationTests", key = "build-test-executive" },
    { name = "MinaArtifactBullseye", key = "daemon-devnet-bullseye" },
    { name = "MinaArtifactBullseye", key = "archive-bullseye" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
        S.strictlyStart (S.contains "src"),
        S.strictlyStart (S.contains "dockerfiles"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Test/TestnetIntegrationTest"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Command/TestExecutive"),
        S.strictlyStart (S.contains "automation/terraform/modules/o1-integration"),
        S.strictlyStart (S.contains "automation/terraform/modules/kubernetes/testnet")
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
    TestExecutive.execute "block-prod-prio" dependsOn,
    TestExecutive.execute "medium-bootstrap" dependsOn,
    TestExecutive.execute "archive-node" dependsOn

  ]
}
