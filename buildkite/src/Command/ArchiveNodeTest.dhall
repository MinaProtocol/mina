let Artifacts = ../Constants/Artifacts.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let key = "archive-node-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    [ "ARCHIVE_TEST_APP=mina-archive-node-test"
                    , "MINA_TEST_NETWORK_DATA=/etc/mina/test/archive/sample_db"
                    ]
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.Script
                            "src/test/archive/sample_db/archive_db.sql"
                        )
                    )
                    ( Artifacts.fullDockerTag
                        Artifacts.Tag::{
                        , artifact = Artifacts.Type.FunctionalTestSuite
                        , buildFlags = BuildFlags.Type.Instrumented
                        }
                    )
                    "./scripts/tests/archive-node-test.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key} && ls -al && ./buildkite/scripts/cache/manager.sh write archive.perf archive-node-test"
                ]
              , label = "Archive: Node Test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
