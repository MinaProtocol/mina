let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "patch-archive-test"

let debs =
      "mina-test-suite,mina-devnet-instrumented,mina-archive-devnet-instrumented,mina-rosetta-devnet"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    [ "PATCH_ARCHIVE_TEST_APP=mina-patch-archive-test"
                    , "NETWORK_DATA_FOLDER=/etc/mina/test/archive/sample_db"
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
