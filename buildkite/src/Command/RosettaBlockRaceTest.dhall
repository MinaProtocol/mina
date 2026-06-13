let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "rosetta-block-race-test"

let debs =
      "mina-mainnet-generic-instrumented,mina-archive-mainnet-instrumented,mina-rosetta-mainnet-generic"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    ([] : List Text)
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.OnlineTarGzDump
                            "https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-2025-11-11_0000.sql.tar.gz"
                        )
                    )
                    ContainerImages.minaToolchainBullseye.amd64
                    debs
                    "./buildkite/scripts/tests/rosetta/block-race-test.sh"
                , Cmd.run
                    "./buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Rosetta: Rosetta Block Race test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
