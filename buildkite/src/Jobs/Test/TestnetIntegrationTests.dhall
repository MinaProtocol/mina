let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let TestExecutive = ../../Command/TestExecutive.dhall

let dependsOn = [
    { name = "MinaArtifactBullseye", key = "daemon-berkeley-bullseye-docker-image" },
    { name = "MinaArtifactBullseye", key = "archive-bullseye-docker-image" }
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
    name = "TestnetIntegrationTests",
    mode = PipelineMode.Type.Stable
  },
  steps = [
    TestExecutive.execute "peers-reliability" dependsOn,
    TestExecutive.execute "chain-reliability" dependsOn,
    TestExecutive.execute "payment" dependsOn,
    TestExecutive.execute "gossip-consis" dependsOn,
    TestExecutive.execute "block-prod-prio" dependsOn,
    TestExecutive.execute "medium-bootstrap" dependsOn,
    TestExecutive.execute "block-reward" dependsOn,
    TestExecutive.execute "zkapps" dependsOn,
    TestExecutive.execute "zkapps-timing" dependsOn,
    TestExecutive.execute "zkapps-nonce" dependsOn,
    TestExecutive.execute "verification-key" dependsOn
  ]
}
