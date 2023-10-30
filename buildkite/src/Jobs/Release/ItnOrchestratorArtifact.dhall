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
let Profiles = ../../Constants/Profiles.dhall
let DebianVersions = ../../Constants/DebianVersions.dhall

let spec = DockerImage.ReleaseSpec::{
    service="itn-orchestrator",
    step_key="itn-orchestrator-docker-image",
    network="berkeley",
    deps = DebianVersions.dependsOn DebianVersions.DebVersion.Bullseye Profiles.Type.Standard
}

in	

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/ItnOrchestratorArtifact"),
          S.strictlyStart (S.contains "src/app/itn_orchestrator")
        ],
        path = "Release",
        name = "ItnOrchestratorArtifact",
        tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
      },
    steps = [
      DockerImage.generateStep spec
    ]
  }
