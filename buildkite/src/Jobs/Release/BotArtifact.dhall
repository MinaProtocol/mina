let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerImage = ../../Command/DockerImage.dhall

let spec = DockerImage.ReleaseSpec::{
    service="bot",
    step_key="bot-docker-image"
}

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/BotArtifact"),
          S.strictlyStart (S.contains "frontend/bot")
        ],
        path = "Release",
        name = "BotArtifact",
        tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
      },
    steps = [
      DockerImage.generateStep spec
    ]
  }
