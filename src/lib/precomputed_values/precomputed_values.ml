open Core
module T = Genesis_proof.T
include T

let hashes =
  lazy
    (let constraint_constants =
       Genesis_constants.For_unit_tests.Constraint_constants.t
     in
     let proof_level = Genesis_constants.Proof_level.Full in
     let ts =
       Transaction_snark.constraint_system_digests ~constraint_constants ()
     in
     let bs =
       Blockchain_snark.Blockchain_snark_state.constraint_system_digests
         ~proof_level ~constraint_constants ()
     in
     ts @ bs )

let for_unit_tests =
  lazy
    (let open Staged_ledger_diff in
    let protocol_state_with_hashes =
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:
          (let open Genesis_ledger in
          Packed.t for_unit_tests)
        ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
        ~constraint_constants:
          Genesis_constants.For_unit_tests.Constraint_constants.t
        ~consensus_constants:(Lazy.force Consensus.Constants.for_unit_tests)
        ~genesis_body_reference
    in
    { runtime_config = Runtime_config.default
    ; constraint_constants =
        Genesis_constants.For_unit_tests.Constraint_constants.t
    ; proof_level = Genesis_constants.For_unit_tests.Proof_level.t
    ; genesis_constants = Genesis_constants.For_unit_tests.t
    ; genesis_ledger = Genesis_ledger.for_unit_tests
    ; genesis_epoch_data = Consensus.Genesis_epoch_data.for_unit_tests
    ; genesis_body_reference
    ; consensus_constants = Lazy.force Consensus.Constants.for_unit_tests
    ; protocol_state_with_hashes
    ; constraint_system_digests = hashes
    ; proof_data = None
    ; compile_config = Mina_compile_config.For_unit_tests.t
    })
