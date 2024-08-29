let Artifacts = ../Constants/Artifacts.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let Network = ../Constants/Network.dhall

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    ([] : List Text)
                    "./src/test/archive/sample_db/archive_db.sql"
                    Artifacts.Type.Archive
                    (Some Network.Type.Devnet)
                    "./scripts/replayer-test.sh -i src/test/archive/sample_db/replayer_input_file.json -a mina-replayer"
                ]
              , label = "Archive: Replayer test"
              , key = "replayer-test"
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
