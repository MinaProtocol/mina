let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "archive-automode-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    [ "APPS_BUILD_FLAG=instrumented"
                    , "MINA_PROFILE=devnet"
                    , "APPS_BARE_BINARIES=archive.exe:mina-archive,mina.exe:mina"
                    ]
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.OnlineTarGzDump
                            "https://storage.googleapis.com/mina-archive-dumps/devnet-archive-dump-2026-08-19_1700.sql.tar.gz"
                        )
                    )
                    ContainerImages.minaToolchainBookworm.amd64
                    "mina-generic-instrumented,mina-archive-generic-instrumented,mina-devnet-profile,mina-archive-devnet-instrumented"
                    "./buildkite/scripts/archive-automode-test.sh"
                , Cmd.run
                    "buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Archive: Automode hard fork hand-over"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
