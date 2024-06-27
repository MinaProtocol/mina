let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/src/Jobs/Test/NixBuildTest" "dhall"
          , S.exactly "buildkite/scripts/test-nix" "sh"
          , S.strictlyStart (S.contains "nix")
          , S.exactly "flake" "nix"
          , S.exactly "flake" "lock"
          , S.exactly "default" "nix"
          ]
        , path = "Test"
        , name = "NixBuildTest"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{
                  , image = ContainerImages.nixos
                  , privileged = True
                  }
                  "./buildkite/scripts/test-nix.sh \$BUILDKITE_BRANCH"
              ]
            , label = "nix build tests"
            , key = "nix-build-tests"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
