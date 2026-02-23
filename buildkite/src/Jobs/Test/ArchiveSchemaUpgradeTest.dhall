let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "src/app/archive/create_schema" "sql"
          , S.exactly "src/app/archive/drop_tables" "sql"
          , S.exactly "src/app/archive/upgrade_to_mesa" "sql"
          , S.exactly "src/app/archive/downgrade_to_berkeley" "sql"
          , S.exactly "buildkite/src/Jobs/Test/ArchiveSchemaUpgradeTest" "dhall"
          , S.exactly "buildkite/scripts/archive/verify-schema-upgrade" "sh"
          ]
        , path = "Test"
        , name = "ArchiveSchemaUpgradeTest"
        , scope = PipelineScope.AllButPullRequest
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "buildkite/scripts/archive/verify-schema-upgrade.sh --source-branch compatible --target-branch develop"
              ]
            , label = "Archive: Schema upgrade verification"
            , key = "archive-schema-upgrade-test"
            , target = Size.Multi
            , docker = None Docker.Type
            , timeout_in_minutes = Some +30
            }
        ]
      }
