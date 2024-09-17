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
                    (None Network.Type)
                    "./buildkite/scripts/replayer-test.sh"
                ]
              , label = "Archive: Replayer test"
              , key = "replayer-test"
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
