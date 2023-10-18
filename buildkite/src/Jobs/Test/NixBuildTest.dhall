let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "src"),
          S.exactly "buildkite/src/Jobs/Test/NixBuild" "dhall"
        ],
        path = "Test",
        name = "NixBuildTest",
        tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
      },
    steps = [
      Command.build
        Command.Config::{
          commands = [
            Cmd.runInDocker Cmd.Docker::{image = ContainerImages.nixos} "./buildkite/scripts/test-nix.sh"
          ],
          label = "nix build tests",
          key = "nix-build-tests",
          target = Size.Small,
          docker = None Docker.Type
        }
    ]
  }
