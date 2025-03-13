let Artifacts = ../Constants/Artifacts.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let Network = ../Constants/Network.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let key = "archive-node-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    [ "ARCHIVE_TEST_APP=mina-archive-node-test"
                    , "NETWORK_DATA_FOLDER=/etc/mina/test/archive/sample_db"
                    ]
                    "./src/test/archive/sample_db/archive_db.sql"
                    Artifacts.Type.FunctionalTestSuite
                    (None Network.Type)
                    "./scripts/tests/archive-node-test.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Archive: Node Test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
