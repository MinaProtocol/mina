let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let TestExecutive = ../../Command/TestExecutive.dhall

let dependsOn = [
    { name = "TestnetIntegrationTests", key = "build-test-executive" },
    { name = "MinaArtifactBullseye", key = "daemon-berkeley-bullseye-docker-image" },
    { name = "MinaArtifactBullseye", key = "archive-bullseye-docker-image" }
]
let dependsOnJs = [
    { name = "TestnetIntegrationTests", key = "build-test-executive" },
    { name = "TestnetIntegrationTests", key = "build-js-tests" },
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
        S.strictlyStart (S.contains "automation/terraform/modules/kubernetes/testnet"),
        S.strictlyStart (S.contains "automation/buildkite/script/run-test-executive-cloud"),
        S.strictlyStart (S.contains "automation/buildkite/script/run-test-executive-local")
    ],
    path = "Test",
    name = "TestnetIntegrationTests",
    mode = PipelineMode.Type.Stable
  },
  steps = [
    TestExecutive.build "integration_tests",
    TestExecutive.buildJs "integration_tests",
    TestExecutive.executeCloud "peers-reliability" dependsOn,
    TestExecutive.executeCloud "chain-reliability" dependsOn,
    TestExecutive.executeCloud "payment" dependsOn,
    TestExecutive.executeCloud "gossip-consis" dependsOn,
    TestExecutive.executeCloud "block-prod-prio" dependsOn,
    TestExecutive.executeCloud "medium-bootstrap" dependsOn,
    TestExecutive.executeCloud "block-reward" dependsOn,
    TestExecutive.executeCloud "zkapps" dependsOn,
    TestExecutive.executeCloud "zkapps-timing" dependsOn,
    TestExecutive.executeCloud "zkapps-nonce" dependsOn,
    TestExecutive.executeCloud "verification-key" dependsOn,
    TestExecutive.executeLocal "gossip-consis" dependsOn,
    TestExecutive.executeLocal "verification-key" dependsOn,
    TestExecutive.executeLocal "medium-bootstrap" dependsOn,
    TestExecutive.executeWithJs "snarkyjs" dependsOnJs
  ]
}
