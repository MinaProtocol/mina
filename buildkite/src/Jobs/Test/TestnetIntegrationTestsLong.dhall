let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let TestExecutive = ../../Command/TestExecutive.dhall
let Profiles = ../../Constants/Profiles.dhall
let Dockers = ../../Constants/DockerVersions.dhall

let dependsOn = Dockers.dependsOn Dockers.Type.Bullseye Profiles.Type.Standard "daemon-berkeley"
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
        S.strictlyStart (S.contains "automation/terraform/modules/kubernetes/testnet")
    ],
    path = "Test",
    name = "TestnetIntegrationTestsLong",
    mode = PipelineMode.Type.Stable,
    tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
  },
  steps = [
    TestExecutive.execute "hard-fork" dependsOn
  ]
}
