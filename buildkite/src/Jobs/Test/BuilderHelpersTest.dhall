let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "scripts/debian/builder-helpers")
          , S.strictlyStart (S.contains "scripts/debian/tests")
          , S.strictlyStart (S.contains "scripts/export-git-env-vars")
          , S.exactly "buildkite/src/Jobs/Test/BuilderHelpersTest" "dhall"
          ]
        , path = "Test"
        , name = "BuilderHelpersTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Debian
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "./scripts/debian/tests/test_builder_helpers.sh" ]
            , label = "Debian builder-helpers tests"
            , key = "builder-helpers-tests"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
