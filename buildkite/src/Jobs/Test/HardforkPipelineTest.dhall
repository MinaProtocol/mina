let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let B = ../../External/Buildkite.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/src/Jobs/Test/HardforkPipelineTest" "dhall"
          , S.strictlyStart (S.contains "buildkite/scripts/pipeline")
          ]
        , path = "Test"
        , name = "HardforkPipelineTest"
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
                RunInToolchain.runInToolchain
                  [ "BUILDKITE_AGENT_WRITE_TOKEN" ]
                  "./buildkite/scripts/pipeline/run_for_newest_devnet.sh"
            , label = "Hardfork: pipeline test"
            , key = "hard-fork-pipeline-test"
            , target = Size.Small
            , soft_fail = Some (B/SoftFail.Boolean False)
            , docker = None Docker.Type
            , timeout_in_minutes = Some +65
            }
        ]
      }
