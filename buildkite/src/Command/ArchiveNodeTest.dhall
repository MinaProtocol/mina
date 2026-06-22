let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "archive-node-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    [ "ARCHIVE_TEST_APP=mina-archive-node-test"
                    , "MINA_TEST_NETWORK_DATA=src/test/archive/sample_db"
                    , "APPS_BUILD_FLAG=instrumented"
                    , "APPS_BARE_BINARIES=archive_node_tests.exe:mina-archive-node-test,archive.exe:mina-archive,archive_blocks.exe:mina-archive-blocks,replayer.exe:mina-replayer,mina_testnet_signatures.exe:mina,runtime_genesis_ledger.exe:mina-create-genesis"
                    ]
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.Script
                            "src/test/archive/sample_db/archive_db.sql"
                        )
                    )
                    ContainerImages.minaToolchainBullseye.amd64
                    "mina-test-suite,mina-devnet-generic-instrumented,mina-archive-devnet-instrumented"
                    "./scripts/tests/archive-node-test.sh"
                , Cmd.run
                    "buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                , Cmd.run
                    "./buildkite/scripts/cache/manager.sh write-to-dir archive.perf archive-node-test"
                ]
              , label = "Archive: Node Test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
