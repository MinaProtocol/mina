let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let key = "replayer-test"

let debs =
      "mina-devnet-instrumented,mina-archive-devnet-instrumented,mina-rosetta-devnet"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                    ([] : List Text)
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.Script
                            "./src/test/archive/sample_db/archive_db.sql"
                        )
                    )
                    ContainerImages.minaToolchainBullseye.amd64
                    debs
                    "./buildkite/scripts/replayer-test.sh"
                , Cmd.run
                    "buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Archive: Replayer test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
