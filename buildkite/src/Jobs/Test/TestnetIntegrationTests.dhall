let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let TestExecutive = ../../Command/TestExecutive.dhall
let Profiles = ../../Constants/Profiles.dhall
let Dockers = ../../Constants/DockerVersions.dhall

let dependsOn = 
    Dockers.dependsOn Dockers.Type.Bullseye Profiles.Type.Standard "daemon-berkeley"
    # Dockers.dependsOn Dockers.Type.Bullseye Profiles.Type.Standard "archive"

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
    tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ],
    mode = PipelineMode.Type.Stable
  },
  steps = [
    TestExecutive.executeCloud "peers-reliability" dependsOn,
    TestExecutive.executeCloud "chain-reliability" dependsOn,
    TestExecutive.executeLocal "payment" dependsOn,
    TestExecutive.executeCloud "gossip-consis" dependsOn,
    TestExecutive.executeCloud "block-prod-prio" dependsOn,
    TestExecutive.executeCloud "medium-bootstrap" dependsOn,
    TestExecutive.executeCloud "block-reward" dependsOn,
    TestExecutive.executeCloud "zkapps" dependsOn,
    TestExecutive.executeCloud "zkapps-timing" dependsOn,
    TestExecutive.executeCloud "zkapps-nonce" dependsOn,
    TestExecutive.executeCloud "verification-key" dependsOn,
    TestExecutive.executeCloud "slot-end" dependsOn,
    TestExecutive.executeCloud "epoch-ledger" dependsOn
  ]
}
