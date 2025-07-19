let RunInToolchain = ./RunInToolchain.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let key = "mock-coordinator-test"

in  { step =
            \(dependsOn : List Command.TaggedKey.Type)
        ->  Command.build
              Command.Config::{
              , commands =
                  RunInToolchain.runInToolchain
                    [ "DUMPED_SPEC_PATH=/tmp/mock-coordinator-spec/specs"
                    , "PROOF_OUTPUT_PATH=/tmp/mock-coordinator-test/proofs"
                    , "MINA_APP=mina"
                    , "MOCK_SNARK_WORKER_COORDINATOR=mina_mock_snark_worker_coordinator"
                    ]
                    "./buildkite/scripts/tests/mock-coordinator.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}"
              , label = "Snark: Mock Coordinator test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
