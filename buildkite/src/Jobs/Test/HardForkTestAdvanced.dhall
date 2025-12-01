let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/src/Jobs/Test/HardForkTest" "dhall"
          , S.strictlyStart (S.contains "scripts/hardfork")
          , S.strictlyStart (S.contains "nix")
          , S.exactly "flake" "nix"
          , S.exactly "flake" "lock"
          , S.exactly "default" "nix"
          ]
        , path = "Test"
        , name = "HardForkTestAdvanced"
        , scope = PipelineScope.AllButPullRequest
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Hardfork
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{
                  , image = ContainerImages.nixos
                  , privileged = True
                  , useBash = False
                  }
                  "./scripts/hardfork/build-and-test.sh --fork-from origin/lyh/test-hf-test-go-advanced-hf-config --fork-method advanced"
              ]
            , label = "hard fork test - advanced mode"
            , key = "hard-fork-test-advanced"
            , target = Size.Integration
            , soft_fail = Some (B/SoftFail.Boolean False)
            , docker = None Docker.Type
            , timeout_in_minutes = Some +420
            }
        ]
      }
