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

let ContainterImages = ../../Constants/ContainerImages.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/src/Jobs/Test/HFTest" "dhall"
          , S.strictlyStart (S.contains "scripts/hardfork")
          , S.strictlyStart (S.contains "nix")
          , S.exactly "flake" "nix"
          , S.exactly "flake" "lock"
          , S.exactly "default" "nix"
          ]
        , path = "Test"
        , name = "HFTest"
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
              [ Cmd.run
                  "MINA_DEB_CODENAME=focal ./scripts/hardfork/build-and-test.sh --mode docker --context ci --fork-branch \$BUILDKITE_BRANCH --toolchain ${ContainterImages.minaToolchain}"
              ]
            , label = "hard fork test"
            , key = "hard-fork-test"
            , target = Size.Integration
            , soft_fail = Some (B/SoftFail.Boolean False)
            , docker = None Docker.Type
            , timeout_in_minutes = Some +420
            }
        ]
      }
