let Artifacts = ../Constants/Artifacts.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let Network = ../Constants/Network.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let key = "patch-archive-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    [ "PATCH_ARCHIVE_TEST_APP=mina-patch-archive-test"
                    , "NETWORK_DATA_FOLDER=/etc/mina/test/archive/sample_db"
                    ]
                    "./src/test/archive/sample_db/archive_db.sql"
                    Artifacts.Type.FunctionalTestSuite
                    (None Network.Type)
                    "./scripts/patch-archive-test.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key} dev"
                ]
              , label = "Archive: Patch Archive test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
