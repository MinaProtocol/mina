(* Regression tests for the blockchain step circuit's constraint system.
   These run [Blockchain_snark.check], which only builds the step circuit's
   constraint system (no Pickles recursive verification); at
   [Proof_level.No_check] the prev/txn proofs are never inspected, so dummy
   proofs suffice. A baseline witness that the circuit itself produces is
   accepted; a variant witness is rejected. *)

open Core_kernel
module Blockchain_snark = Blockchain_snark.Blockchain_snark_state

module G = (val Genesis_constants.profiled ())

let constraint_constants = G.constraint_constants

let consensus_constants =
  Consensus.Constants.create ~constraint_constants
    ~protocol_constants:G.genesis_constants.protocol

let genesis_ledger =
  Consensus.Genesis_data.Ledger.to_hashed Genesis_ledger.for_unit_tests

let genesis_epoch_data =
  Consensus.Genesis_data.Epoch.to_hashed
    Consensus.Genesis_data.Epoch.for_unit_tests

let genesis_body_reference = Staged_ledger_diff.genesis_body_reference

let genesis_epoch_ledger = Genesis_ledger.Packed.t Genesis_ledger.for_unit_tests

(* The state before genesis; the circuit produces genesis from it. *)
let negative_one_state =
  Mina_state.Protocol_state.negative_one ~genesis_ledger ~genesis_epoch_data
    ~constraint_constants ~consensus_constants ~genesis_body_reference

(* Full genesis protocol state (= the circuit's output from negative-one). *)
let genesis_with_hash =
  Mina_state.Genesis_protocol_state.t ~genesis_ledger ~genesis_epoch_data
    ~constraint_constants ~consensus_constants ~genesis_body_reference

let genesis_protocol_state = genesis_with_hash.data

let neg1_ledger_proof_statement =
  negative_one_state |> Mina_state.Protocol_state.blockchain_state
  |> Mina_state.Blockchain_state.ledger_proof_statement

let consensus_handler =
  Consensus.Data.Prover_state.precomputed_handler ~constraint_constants
    ~genesis_epoch_ledger

(* An arbitrary ledger hash, distinct from the real one. *)
let other_ledger_hash =
  Snark_params.Tick.Field.of_int 999999 |> Mina_base.Frozen_ledger_hash.of_hash

let variant_ledger_proof_statement =
  { neg1_ledger_proof_statement with
    target =
      { neg1_ledger_proof_statement.target with
        first_pass_ledger = other_ledger_hash
      ; second_pass_ledger = other_ledger_hash
      }
  }

(* A genesis blockchain_state variant used as the negative case. *)
let variant_blockchain_state =
  let genesis_bs =
    Mina_state.Protocol_state.blockchain_state genesis_protocol_state
  in
  { genesis_bs with ledger_proof_statement = variant_ledger_proof_statement }

let variant_transition : Mina_state.Snark_transition.Value.t =
  { blockchain_state = variant_blockchain_state
  ; consensus_transition = Consensus.Data.Consensus_transition.genesis
  ; pending_coinbase_update = Mina_base.Pending_coinbase.Update.genesis
  }

(* A transaction statement matching the previous state. *)
let matching_txn_snark : Transaction_snark.Statement.With_sok.t =
  { neg1_ledger_proof_statement with
    sok_digest = Mina_base.Sok_message.Digest.default
  }

(* Genesis protocol state is what the circuit produces from negative_one. *)
let baseline_new_state = genesis_protocol_state

let baseline_blockchain_state =
  Mina_state.Protocol_state.blockchain_state genesis_protocol_state

(* Genesis state with only blockchain_state swapped, so every other field
   matches what the circuit computes. *)
let variant_new_state =
  Mina_state.Protocol_state.create_value
    ~previous_state_hash:
      (Mina_state.Protocol_state.previous_state_hash genesis_protocol_state)
    ~genesis_state_hash:
      (Mina_state.Protocol_state.hashes negative_one_state).state_hash
    ~blockchain_state:variant_blockchain_state
    ~consensus_state:
      (Mina_state.Protocol_state.consensus_state genesis_protocol_state)
    ~constants:(Mina_state.Protocol_state.constants genesis_protocol_state)

let baseline_transition : Mina_state.Snark_transition.Value.t =
  { blockchain_state = baseline_blockchain_state
  ; consensus_transition = Consensus.Data.Consensus_transition.genesis
  ; pending_coinbase_update = Mina_base.Pending_coinbase.Update.genesis
  }

(* --- Tests --- *)

let test_baseline_accepted () =
  let witness : Blockchain_snark.Witness.t =
    { prev_state = negative_one_state
    ; prev_state_proof = Lazy.force Mina_base.Proof.transaction_dummy
    ; transition = baseline_transition
    ; txn_snark = matching_txn_snark
    ; txn_snark_proof = Lazy.force Mina_base.Proof.transaction_dummy
    }
  in
  let result =
    Blockchain_snark.check witness ~handler:consensus_handler
      ~proof_level:Genesis_constants.Proof_level.No_check ~constraint_constants
      baseline_new_state
  in
  match result with
  | Ok () ->
      ()
  | Error e ->
      Alcotest.fail
        (Printf.sprintf "Baseline witness rejected: %s" (Error.to_string_hum e))

let test_variant_rejected () =
  (* Public input must hash to what the circuit computes; variant_new_state
     differs from genesis only in its blockchain_state. *)
  let witness : Blockchain_snark.Witness.t =
    { prev_state = negative_one_state
    ; prev_state_proof = Lazy.force Mina_base.Proof.transaction_dummy
    ; transition = variant_transition
    ; txn_snark = matching_txn_snark
    ; txn_snark_proof = Lazy.force Mina_base.Proof.transaction_dummy
    }
  in
  let circuit_result =
    Blockchain_snark.check witness ~handler:consensus_handler
      ~proof_level:Genesis_constants.Proof_level.No_check ~constraint_constants
      variant_new_state
  in
  let circuit_accepts = Result.is_ok circuit_result in
  let variant_snarked =
    Mina_state.Snarked_ledger_state.snarked_ledger_hash
      variant_ledger_proof_statement
  in
  let real_snarked =
    Mina_state.Snarked_ledger_state.snarked_ledger_hash
      neg1_ledger_proof_statement
  in
  let hashes_differ =
    not (Mina_base.Frozen_ledger_hash.equal variant_snarked real_snarked)
  in
  (* The circuit must reject this witness. *)
  if circuit_accepts then Alcotest.fail "Circuit accepted a variant witness."
  else if not hashes_differ then
    Alcotest.fail "Hashes unexpectedly equal — test setup error"
  else ()

let tests =
  [ ( "baseline"
    , [ Alcotest.test_case "baseline witness accepted" `Quick
          test_baseline_accepted
      ] )
  ; ( "variant"
    , [ Alcotest.test_case "variant witness rejected" `Quick
          test_variant_rejected
      ] )
  ]

let () =
  (* The witnesses here are built from the dev unit-test genesis fixtures, whose
     Merkle depth only lines up with the dev profile's constraint constants;
     under devnet/mainnet (depth 35) the baseline case hits a path-length
     mismatch in the consensus part of the circuit. The property exercised here
     has no ledger-depth dependence, so running under dev is sufficient.
     [profile-dependent-tests.sh] also runs this directory under devnet/mainnet
     (for the stats and VK regression tests), so skip there. *)
  match Node_config.profile with
  | "dev" ->
      Alcotest.run "Blockchain step circuit" tests
  | other ->
      Printf.printf
        "Skipping blockchain step circuit test under profile %s (dev-only \
         fixtures)\n\
         %!"
        other
