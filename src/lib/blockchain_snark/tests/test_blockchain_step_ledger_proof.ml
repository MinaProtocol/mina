(* Regression tests for the blockchain step circuit's constraint system.
   These run [Blockchain_snark.check], which only builds the step circuit's
   constraint system (no Pickles recursive verification); at
   [Proof_level.No_check] the prev/txn proofs are never inspected, so dummy
   proofs suffice. A baseline witness that the circuit itself produces is
   accepted; a variant witness is rejected. *)

open Core_kernel
module Blockchain_snark = Blockchain_snark.Blockchain_snark_state

let constraint_constants = Genesis_constants.Compiled.constraint_constants

let consensus_constants =
  Consensus.Constants.create ~constraint_constants
    ~protocol_constants:Genesis_constants.Compiled.genesis_constants.protocol

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

(* --- Changed-path forgery of the trusted snarked ledger hash ---

   [test_variant_rejected] above covers the "nothing_changed = true" path, where
   an equality constraint pins the new ledger statement to the previous one. The
   tests below cover the sibling "changed" path (nothing_changed = false), i.e. a
   block that emits a new ledger transition. On that path the only constraint on
   the recorded new ledger statement is [valid_ledgers_at_merge], and that check
   reads the statement's source / connecting / local-source ledgers but never its
   target ledgers. The snarked ledger hash a light client trusts is precisely
   [target.first_pass_ledger], so on the changed path it is left unconstrained: a
   producer can run a real transaction (obtaining a valid txn statement) yet
   record an arbitrary snarked ledger hash in the new state, and the step circuit
   still accepts it. *)

(* An honest-looking target for the verified txn statement, distinct from the
   previous state's, so that [txn_statement_ledger_hashes_equal previous
   txn_snark] is false and the circuit takes the CHANGED path
   (nothing_changed = false). *)
let honest_txn_target_hash =
  Snark_params.Tick.Field.of_int 111111 |> Mina_base.Frozen_ledger_hash.of_hash

(* txn_snark that drives the changed path. It differs from [previous] only in
   [target.first_pass_ledger]; fee_excess (0), supply_increase (0) and the two
   pending-coinbase stacks are inherited from [matching_txn_snark] (= the neg-one
   statement). Those stacks are exactly what the genesis coinbase pop expects:
   [pop_coinbases] returns the tree's oldest stack as [deleted_stack] regardless
   of [proof_emitted], so the same values the baseline uses satisfy the two
   [Pending_coinbase.Stack.equal_var] checks here too. *)
let changed_path_txn_snark : Transaction_snark.Statement.With_sok.t =
  { matching_txn_snark with
    target =
      { matching_txn_snark.target with
        first_pass_ledger = honest_txn_target_hash
      }
  }

(* The recorded new ledger statement, with a FORGED target register. Every field
   [valid_ledgers_at_merge] actually reads (source / connecting-left /
   second-pass-source / local-source) is kept equal to the previous statement, so
   the sole changed-path gate is satisfied; only the unread target ledgers are
   forged. Both [first_pass_ledger] and [second_pass_ledger] of the target are
   forged to show the whole target register is free on the changed path, not just
   the snarked-hash field ([target.first_pass_ledger]). Note the forged value
   (999999) differs from [changed_path_txn_snark.target] (111111): the proposed
   fix binds txn_snark.target = current.target, so this witness must be rejected
   once that binding exists. *)
let forged_ledger_proof_statement =
  { neg1_ledger_proof_statement with
    target =
      { neg1_ledger_proof_statement.target with
        first_pass_ledger = other_ledger_hash
      ; second_pass_ledger = other_ledger_hash
      }
  }

let forged_blockchain_state =
  let genesis_bs =
    Mina_state.Protocol_state.blockchain_state genesis_protocol_state
  in
  { genesis_bs with ledger_proof_statement = forged_ledger_proof_statement }

let forged_transition : Mina_state.Snark_transition.Value.t =
  { blockchain_state = forged_blockchain_state
  ; consensus_transition = Consensus.Data.Consensus_transition.genesis
  ; pending_coinbase_update = Mina_base.Pending_coinbase.Update.genesis
  }

let new_state_of_blockchain_state blockchain_state =
  Mina_state.Protocol_state.create_value
    ~previous_state_hash:
      (Mina_state.Protocol_state.previous_state_hash genesis_protocol_state)
    ~genesis_state_hash:
      (Mina_state.Protocol_state.hashes negative_one_state).state_hash
    ~blockchain_state
    ~consensus_state:
      (Mina_state.Protocol_state.consensus_state genesis_protocol_state)
    ~constants:(Mina_state.Protocol_state.constants genesis_protocol_state)

let forged_new_state = new_state_of_blockchain_state forged_blockchain_state

(* Honest changed-path statement: identical to the forged one EXCEPT the target
   matches the verified txn statement's target ([first_pass_ledger] =
   [honest_txn_target_hash], and the rest of the target = the previous state's,
   same as [changed_path_txn_snark]). This is the positive discriminator: a
   changed-path witness whose recorded target equals the proven target must be
   accepted, today and after the fix. It is as cheap to build as the forged case
   precisely because [valid_ledgers_at_merge] never reads the target, so honest
   and forged witnesses differ only in the (currently unconstrained) target. *)
let honest_ledger_proof_statement =
  { neg1_ledger_proof_statement with
    target =
      { neg1_ledger_proof_statement.target with
        first_pass_ledger = honest_txn_target_hash
      }
  }

let honest_blockchain_state =
  let genesis_bs =
    Mina_state.Protocol_state.blockchain_state genesis_protocol_state
  in
  { genesis_bs with ledger_proof_statement = honest_ledger_proof_statement }

let honest_transition : Mina_state.Snark_transition.Value.t =
  { blockchain_state = honest_blockchain_state
  ; consensus_transition = Consensus.Data.Consensus_transition.genesis
  ; pending_coinbase_update = Mina_base.Pending_coinbase.Update.genesis
  }

let honest_new_state = new_state_of_blockchain_state honest_blockchain_state

(* Control: forge a field [valid_ledgers_at_merge] DOES read
   ([source.first_pass_ledger]). This must be rejected both before and after the
   fix — it confirms the changed-path gate genuinely discriminates and the
   acceptance of the target forgery is a real gap, not a no-op. *)
let control_ledger_proof_statement =
  { neg1_ledger_proof_statement with
    source =
      { neg1_ledger_proof_statement.source with
        first_pass_ledger = other_ledger_hash
      }
  }

let control_blockchain_state =
  let genesis_bs =
    Mina_state.Protocol_state.blockchain_state genesis_protocol_state
  in
  { genesis_bs with ledger_proof_statement = control_ledger_proof_statement }

let control_transition : Mina_state.Snark_transition.Value.t =
  { blockchain_state = control_blockchain_state
  ; consensus_transition = Consensus.Data.Consensus_transition.genesis
  ; pending_coinbase_update = Mina_base.Pending_coinbase.Update.genesis
  }

let control_new_state = new_state_of_blockchain_state control_blockchain_state

let run_changed_path ~transition ~new_state =
  Blockchain_snark.check
    { prev_state = negative_one_state
    ; prev_state_proof = Lazy.force Mina_base.Proof.transaction_dummy
    ; transition
    ; txn_snark = changed_path_txn_snark
    ; txn_snark_proof = Lazy.force Mina_base.Proof.transaction_dummy
    }
    ~handler:consensus_handler
    ~proof_level:Genesis_constants.Proof_level.No_check ~constraint_constants
    new_state

(* Regression guard for the changed-path forgery.

   This test asserts the SECURE behaviour and is expected to FAIL against the
   current circuit: the forged snarked ledger hash is accepted today. The
   accompanying fix — binding the verified txn statement's target to the recorded
   new statement's target on the changed path — makes the circuit reject this
   witness, turning the test green. Until then, a failing run here is the exploit,
   in executable form. *)
let test_changed_path_forged_snarked_hash_rejected () =
  match
    run_changed_path ~transition:forged_transition ~new_state:forged_new_state
  with
  | Error _ ->
      ()
  | Ok () ->
      Alcotest.fail
        "Soundness gap: the blockchain step circuit accepted a forged snarked \
         ledger hash on the changed path (nothing_changed = false). On that \
         path the recorded new statement's target.first_pass_ledger is \
         unconstrained (valid_ledgers_at_merge reads only \
         source/connecting/local-source ledgers), so a producer can record an \
         arbitrary trusted hash while holding a valid txn statement. Bind the \
         verified txn statement's target to the new statement's target on the \
         changed path to close this."

(* Positive discriminator: an honest changed-path transition (recorded target =
   proven target) is accepted. Without this, a broken fix that rejects EVERY
   changed-path witness — not just forged ones — would still make the forged case
   pass; this case fails against such a fix. It must stay green today and after
   the fix. *)
let test_changed_path_honest_transition_accepted () =
  match
    run_changed_path ~transition:honest_transition ~new_state:honest_new_state
  with
  | Ok () ->
      ()
  | Error e ->
      Alcotest.failf
        "Honest changed-path transition rejected: %s. A changed-path witness \
         whose recorded new-statement target matches the verified txn \
         statement's target must be accepted."
        (Error.to_string_hum e)

(* Control: forge a field [valid_ledgers_at_merge] DOES read
   (source.first_pass_ledger). It is rejected by that merge check, which reads the
   source register. This case is FIX-INDEPENDENT: the proposed fix binds the
   target register, not the source, so — unlike the forged-target case — this one
   stays rejected both before and after the fix; the two do not flip together.
   Asserting the failure is a circuit "Constraint unsatisfied" (rather than any
   Error, e.g. a witness/setup error) confirms it is the merge gate rejecting it. *)
let test_changed_path_constrained_field_rejected () =
  match
    run_changed_path ~transition:control_transition ~new_state:control_new_state
  with
  | Error e ->
      let msg = Error.to_string_hum e in
      if String.is_substring msg ~substring:"Constraint unsatisfied" then ()
      else
        Alcotest.failf
          "Control was rejected, but not by a circuit constraint as expected \
           (valid_ledgers_at_merge on source.first_pass_ledger): %s"
          msg
  | Ok () ->
      Alcotest.fail
        "Control failed: the circuit accepted a forged source ledger hash, \
         which valid_ledgers_at_merge is supposed to reject. The changed-path \
         gate is not discriminating as expected."

let tests =
  [ ( "baseline"
    , [ Alcotest.test_case "baseline witness accepted" `Quick
          test_baseline_accepted
      ] )
  ; ( "variant"
    , [ Alcotest.test_case "variant witness rejected" `Quick
          test_variant_rejected
      ] )
  ; ( "changed-path snarked ledger hash"
    , [ Alcotest.test_case "honest changed-path transition accepted" `Quick
          test_changed_path_honest_transition_accepted
      ; Alcotest.test_case "forged snarked ledger hash rejected on changed path"
          `Quick test_changed_path_forged_snarked_hash_rejected
      ; Alcotest.test_case "forged merge-constrained ledger field rejected"
          `Quick test_changed_path_constrained_field_rejected
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
