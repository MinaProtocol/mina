let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let key = "dump-slot-ledger-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    ([] : List Text)
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.Script
                            "src/test/archive/sample_db/archive_db.sql"
                        )
                    )
                    ( Artifacts.fullDockerTag
                        Artifacts.Tag::{
                        , artifact = Artifacts.Type.Archive
                        , buildFlags = BuildFlags.Type.Instrumented
                        }
                    )
                    "./buildkite/scripts/dump-slot-test.sh"
                ]
              , label = "Archive: Dump Slot test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
