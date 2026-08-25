let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let key = "archive-automode-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    ([] : List Text)
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.OnlineTarGzDump
                            "https://storage.googleapis.com/mina-archive-dumps/devnet-archive-dump-2026-08-19_1700.sql.tar.gz"
                        )
                    )
                    ( Artifacts.fullDockerTag
                        Artifacts.Tag::{
                        , artifact = Artifacts.Type.FunctionalTestSuite
                        , buildFlags = BuildFlags.Type.Instrumented
                        }
                    )
                    "./buildkite/scripts/archive-automode-test.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Archive: Automode hard fork hand-over"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
