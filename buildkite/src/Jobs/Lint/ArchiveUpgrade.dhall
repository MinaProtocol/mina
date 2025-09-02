let B = ../../External/Buildkite.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "src/app/archive/create_schema" "sql"
          , S.exactly "src/app/archive/drop_tables" "sql"
          ]
        , path = "Lint"
        , name = "ArchiveUpgrade"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Lint ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "buildkite/scripts/archive/upgrade-script-check.sh --mode assert --branch develop" ]
            , label = "Archive: Check upgrade script need"
            , key = "archive-check-upgrade-script"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
