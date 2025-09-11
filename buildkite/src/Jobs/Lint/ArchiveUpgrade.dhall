let SelectFiles = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ SelectFiles.exactly "src/app/archive/create_schema" "sql"
          , SelectFiles.exactly "src/app/archive/drop_tables" "sql"
          , SelectFiles.exactly "src/app/archive/upgrade-to-mesa" "sql"
          , SelectFiles.exactly "src/app/archive/downgrade-to-berkeley" "sql"
          , SelectFiles.exactly "buildkite/src/Jobs/Lint/ArchiveUpgrade" "dhall"
          , SelectFiles.exactly
              "buildkite/scripts/archive/upgrade-script-check"
              "sh"
          ]
        , path = "Lint"
        , name = "ArchiveUpgrade"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Lint ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "buildkite/scripts/archive/upgrade-script-check.sh --mode verbose --branch develop"
              ]
            , label = "Archive: Check upgrade script need"
            , key = "archive-check-upgrade-script"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
