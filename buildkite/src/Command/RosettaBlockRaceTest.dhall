let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let key = "rosetta-block-race-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ RunWithPostgres.runInDockerWithPostgresConn
                    ([] : List Text)
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.OnlineTarGzDump
                            "https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-2025-11-11_0000.sql.tar.gz"
                        )
                    )
                    ( Artifacts.fullDockerTag
                        Artifacts.Tag::{
                        , artifact = Artifacts.Type.FunctionalTestSuite
                        , buildFlags = BuildFlags.Type.Instrumented
                        }
                    )
                    (     "./buildkite/scripts/tests/rosetta-block-race-test.sh "
                      ++  "&& ./buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                    )
                ]
              , label = "Rosetta: Rosetta Block Race test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
