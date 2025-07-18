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
                    (     "mkdir -p /tmp/mock-coordinator-test "
                      ++  "&& mkdir -p /tmp/mock-coordinator-test/proofs "
                      ++  "&& mkdir -p /tmp/mock-coordinator-test/specs "
                      ++  "&&  ./buildkite/scripts/cache/manager.sh read --root test_data ./scripts/tests/mock_coordinator.sh "
                      ++  "&& tar -xzf ./test_data/mock_coordinator_test_specs.tar.gz -C /tmp/mock-coordinator-test/specs "
                      ++  "&&  ./scripts/tests/mock_coordinator.sh "
                    )
              , label = "Snark: Mock Coordinator test"
              , key = key
              , target = Size.Large
              , depends_on = dependsOn
              }
    }
