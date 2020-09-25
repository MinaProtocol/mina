let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let jobDocker = Cmd.Docker::{image = (../../Constants/ContainerImages.dhall).codaToolchain}

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [ S.contains "helm", S.strictly (S.contains "Chart.yaml") ],
      name = "HelmRelease"
    },
    steps = [
      Command.build
        Command.Config::{
          commands = [ Cmd.run "buildkite/scripts/helm-release.sh" ]
          , label = "Helm chart release steps"
          , key = "release-helm-chart"
          , target = Size.Medium
          , docker = None Docker.Type
          , artifact_paths = [ S.contains "sync_dir/*" ]
        }
    ]
  }
