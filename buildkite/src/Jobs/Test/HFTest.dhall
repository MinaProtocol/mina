let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let PipelineMode = ../../Pipeline/Mode.dhall

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
          S.exactly "buildkite/src/Jobs/Test/HFTest" "dhall",
          S.strictlyStart (S.contains "scripts/hardfork"),
          S.strictlyStart (S.contains "nix"),
          S.exactly "flake" "nix",
          S.exactly "flake" "lock",
          S.exactly "default" "nix"
        ],
        path = "Test",
        name = "HFTest",
        mode = PipelineMode.Type.Stable,
        tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
      },
    steps = [
      Command.build
        Command.Config::{
          commands = [
            Cmd.runInDocker Cmd.Docker::{
              image = ContainerImages.nixos,
              privileged = True
            } "./scripts/hardfork/build-and-test.sh $BUILDKITE_BRANCH"
          ],
          label = "hard fork test",
          key = "hard-fork-test",
          target = Size.Small,
          docker = None Docker.Type,
          timeout_in_minutes = Some 420
        }
    ]
  }
