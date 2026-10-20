let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "src/app/archive/create_schema" "sql"
          , S.exactly "src/app/archive/drop_tables" "sql"
          , S.exactly "src/app/archive/upgrade" "sql"
          , S.exactly "src/app/archive/downgrade" "sql"
          , S.exactly
              "buildkite/src/Jobs/Test/ArchiveSchemaUpgradeFromCompatibleTest"
              "dhall"
          , S.exactly "buildkite/scripts/archive/verify-schema-upgrade" "sh"
          ]
        , path = "Test"
        , name = "ArchiveSchemaUpgradeFromCompatibleTest"
        , scope = PipelineScope.AllButPullRequest
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          ]
        , includeIf =
          [ Expr.Type.DescendantOf
              { ancestor = MainlineBranch.Type.Develop
              , reason =
                  "Develop reaches production by hardfork: upgrade from compatible"
              }
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "buildkite/scripts/archive/verify-schema-upgrade.sh from-branch --from-branch compatible"
              ]
            , label = "Archive: Schema upgrade from compatible"
            , key = "archive-schema-upgrade-from-compatible-test"
            , target = Size.Multi
            , docker = None Docker.Type
            , timeout_in_minutes = Some +30
            }
        ]
      }
