let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "dump-slot-ledger-test"

let debs = "mina-archive-devnet-instrumented"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    [ "APPS_BUILD_FLAG=instrumented"
                    , "APPS_BARE_BINARIES=dump_slot_ledger.exe:mina-dump-slot-ledger"
                    ]
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.Script
                            "src/test/archive/sample_db/archive_db.sql"
                        )
                    )
                    ContainerImages.minaToolchainBullseye.amd64
                    debs
                    "./buildkite/scripts/dump-slot-test.sh"
                ]
              , label = "Archive: Dump Slot test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
