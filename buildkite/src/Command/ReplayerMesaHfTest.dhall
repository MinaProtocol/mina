let B = ../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let RunWithPostgres = ./RunWithPostgres.dhall

let key = "replayer-mesa-hf-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run
                    "cp /var/storagebox/test_data/develop/replayer_mesa/mina-devnet-config_*.deb ./src/test/archive/sample_mesa_hf_db/"
                , RunWithPostgres.runInDockerWithPostgresConn
                    ([] : List Text)
                    ( Some
                        ( RunWithPostgres.ScriptOrArchive.Archive
                            { Script = "mesa_hf_dry_run_db.sql"
                            , Archive =
                                "./src/test/archive/sample_mesa_hf_db/mesa_hf_dry_run_db.sql.tar.gz"
                            }
                        )
                    )
                    ( Artifacts.fullDockerTag
                        Artifacts.Tag::{
                        , artifact = Artifacts.Type.FunctionalTestSuite
                        , buildFlags = BuildFlags.Type.Instrumented
                        }
                    )
                    "./buildkite/scripts/replayer-mesa-hf-test.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Archive: Replayer mesa hard fork test"
              , key = key
              , target = Size.Large
              , soft_fail = Some (B/SoftFail.Boolean True)
              , depends_on = dependsOn
              }
    }
