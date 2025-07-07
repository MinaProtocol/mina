let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let key = "replayer-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    ([] : List Text)
                    "./src/test/archive/sample_db/archive_db.sql"
                    ( Artifacts.fullDockerTag
                        Artifacts.Tag::{
                        , artifact = Artifacts.Type.FunctionalTestSuite
                        , buildFlags = BuildFlags.Type.Instrumented
                        }
                    )
                    "./buildkite/scripts/replayer-test.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Archive: Replayer test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
