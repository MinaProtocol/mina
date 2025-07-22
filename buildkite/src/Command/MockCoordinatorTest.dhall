let Command = ./Base.dhall

let Size = ./Size.dhall

let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Cmd = ../Lib/Cmds.dhall

let key = "mock-coordinator-test"

let minaDocker =
      Artifacts.fullDockerTag
        Artifacts.Tag::{
        , artifact = Artifacts.Type.FunctionalTestSuite
        }

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                [ Cmd.run
                    "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && echo \\\${MINA_DOCKER_TAG}"
                , Cmd.runInDocker
                    Cmd.Docker::{
                    , image = minaDocker
                    , extraEnv =
                      [ "DUMPED_SPEC_PATH=/tmp/mock-coordinator-spec/specs"
                      , "PROOF_OUTPUT_PATH=/tmp/mock-coordinator-test/proofs"
                      , "MINA_APP=mina"
                      , "MOCK_SNARK_WORKER_COORDINATOR=mina_mock_snark_worker_coordinator"
                      ]
                    }
                    "./buildkite/scripts/tests/mock-coordinator.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}"
                ]
              , label = "Snark: Mock Coordinator test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
