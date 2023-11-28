let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let ConnectToTestnet = ../../Command/ConnectToTestnet.dhall
let Profiles = ../../Constants/Profiles.dhall
let Dockers = ../../Constants/DockerVersions.dhall

let dependsOn = Dockers.dependsOn Dockers.Type.Bullseye Profiles.Type.Standard "daemon-berkeley"

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
      S.strictlyStart (S.contains "src"),
      S.exactly "buildkite/scripts/connect-to-berkeley" "sh",
      S.exactly "buildkite/src/Jobs/Test/ConnectToBerkeley" "dhall",
      S.exactly "buildkite/src/Command/ConnectToTestnet" "dhall"
    ],
    path = "Test",
    name = "ConnectToBerkeley",
    tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
  },
  steps = [
    ConnectToTestnet.step dependsOn
  ]
}
