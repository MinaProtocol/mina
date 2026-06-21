let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "patch-archive-test"

let debs =
      "mina-test-suite,mina-devnet-generic-instrumented,mina-archive-devnet-instrumented"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    [ "PATCH_ARCHIVE_TEST_APP=mina-patch-archive-test"
                    , "NETWORK_DATA_FOLDER=src/test/archive/sample_db"
                    , "APPS_BUILD_FLAG=instrumented"
                    , "APPS_BARE_BINARIES=patch_archive_test.exe:mina-patch-archive-test,extract_blocks.exe:mina-extract-blocks,missing_blocks_auditor.exe:mina-missing-blocks-auditor,archive_blocks.exe:mina-archive-blocks,replayer.exe:mina-replayer,mina_testnet_signatures.exe:mina,runtime_genesis_ledger.exe:mina-create-genesis"
                    , "APPS_BARE_SCRIPTS=scripts/archive/missing-blocks-guardian.sh:mina-missing-blocks-guardian"
                    ]
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.Script
                            "./src/test/archive/sample_db/archive_db.sql"
                        )
                    )
                    ContainerImages.minaToolchainBullseye.amd64
                    debs
                    "./scripts/patch-archive-test.sh"
                , Cmd.run
                    "buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Archive: Patch Archive test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
