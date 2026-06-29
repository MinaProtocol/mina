let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "rosetta-block-race-test"

let debs = "mina-mainnet-generic,mina-archive-mainnet,mina-rosetta-mainnet"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    [ "APPS_NETWORK=mainnet"
                    , "APPS_BARE_BINARIES=mina_mainnet_signatures.exe:mina,archive.exe:mina-archive,rosetta_mainnet_signatures.exe:mina-rosetta"
                    ]
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.OnlineTarGzDump
                            "https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-2025-11-11_0000.sql.tar.gz"
                        )
                    )
                    ContainerImages.minaToolchainBullseye.amd64
                    debs
                    "./buildkite/scripts/tests/rosetta/block-race-test.sh"
                ]
              , label = "Rosetta: Rosetta Block Race test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
