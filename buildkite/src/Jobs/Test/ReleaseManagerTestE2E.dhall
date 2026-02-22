let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let command_key = "release-manager-tests-e2e"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/scripts/release")
          , S.strictlyStart (S.contains "scripts/debian")
          , S.strictlyStart (S.contains "scripts/docker")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/ReleaseManagerTest")
          , S.exactly "buildkite/scripts/tests/release-manager/test-e2e" "sh"
          , S.exactly "buildkite/scripts/tests/release-manager/lib" "sh"
          ]
        , path = "Test"
        , name = "ReleaseManagerTestE2E"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Release
          ]
        , scope = PipelineScope.AllButPullRequest
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "AWS_DEFAULT_REGION=us-west-2 ./buildkite/scripts/tests/release-manager/test-e2e.sh"
              ]
            , label = "Release Manager Tests E2E"
            , key = command_key
            , target = Size.Small
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "*.log" ]
            }
        ]
      }
