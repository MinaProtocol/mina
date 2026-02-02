let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let command_key = "release-manager-tests"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/scripts/release")
          , S.strictlyStart (S.contains "scripts/debian")
          , S.strictlyStart (S.contains "scripts/docker")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/ReleaseManagerTest")
          , S.exactly "buildkite/scripts/tests/release-manager-test" "sh"
          ]
        , path = "Test"
        , name = "ReleaseManagerTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Release
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "AWS_DEFAULT_REGION=us-west-2 ./buildkite/scripts/tests/release-manager-test.sh"
              ]
            , label = "Release Manager Tests"
            , key = command_key
            , target = Size.Small
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "*.log" ]
            }
        ]
      }
