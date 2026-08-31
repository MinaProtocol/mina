(** End-to-end test for the SNARK work the uptime service attaches to a
    submission when the block's terminal transaction is a zkApp command.

    This drives the real production function,
    [Uptime_service.Uptime_snark_worker.extract_terminal_zk_segment], over a
    real generated ledger and zkApp command: the transaction is applied, real
    segment witnesses are produced by
    [Transaction_snark.zkapp_command_witnesses_exn], the terminal segment is
    located by its target staged ledger hash, and the statement that would be
    handed to the prover is inspected.

    It stops short of producing a proof — that needs a proving circuit and
    minutes of runtime — so what it pins down is that the statement reaching the
    prover carries the submitter's sok digest rather than the placeholder. That
    is the defect reported as mina#19299: the placeholder survived, and every
    resulting proof attested to the empty sok message and was rejected by
    [delegation_verify]. *)

open Core
open Async
open Mina_base

let constraint_constants =
  Genesis_constants.For_unit_tests.Constraint_constants.t

let genesis_constants = Genesis_constants.For_unit_tests.t

let signature_kind = Mina_signature_kind.Testnet

let protocol_state_body =
  lazy
    ( (Lazy.force Precomputed_values.for_unit_tests).protocol_state_with_hashes
        .data |> Mina_state.Protocol_state.body )

(** A ledger plus a zkApp command that applies cleanly against it. The generator
    defaults its verification key to [Pickles.Side_loaded.Verification_key.dummy],
    so no proving circuit is compiled here. *)
let generate_zkapp_command_and_ledger () =
  let user_command, _fee_payer_keypair, _keymap, ledger =
    Quickcheck.random_value
      ~seed:(`Deterministic "uptime-service-zkapp-terminal-segment")
      (Mina_generators.User_command_generators.zkapp_command_with_ledger
         ~genesis_constants ~constraint_constants () )
  in
  match user_command with
  | User_command.Zkapp_command zkapp_command ->
      (Zkapp_command.Valid.forget zkapp_command, ledger)
  | User_command.Signed_command _ ->
      failwith "generator produced a signed command, expected a zkApp command"

(** Mirrors what the daemon hands the uptime snark worker: the transaction is
    applied first-pass against a mask, and the resulting ledgers become the
    witness's sparse ledgers. *)
let build_witness ~ledger ~zkapp_command ~global_slot =
  let state_body = Lazy.force protocol_state_body in
  let second_pass_ledger =
    let mask =
      Mina_ledger.Ledger.Mask.create ~depth:(Mina_ledger.Ledger.depth ledger) ()
    in
    let registered = Mina_ledger.Ledger.register_mask ledger mask in
    let _partial =
      Mina_ledger.Ledger.apply_transaction_first_pass ~signature_kind
        ~constraint_constants ~global_slot
        ~txn_state_view:(Mina_state.Protocol_state.Body.view state_body)
        registered
        (Mina_transaction.Transaction.Command (Zkapp_command zkapp_command))
      |> Or_error.ok_exn
    in
    registered
  in
  let accounts_referenced = Zkapp_command.accounts_referenced zkapp_command in
  let sparse_of l =
    Mina_ledger.Sparse_ledger.of_ledger_subset_exn l accounts_referenced
  in
  ( Transaction_witness.read_all_proofs_from_disk
      { Transaction_witness.transaction =
          Mina_transaction.Transaction.Command (Zkapp_command zkapp_command)
      ; first_pass_ledger = sparse_of ledger
      ; second_pass_ledger = sparse_of second_pass_ledger
      ; protocol_state_body = state_body
      ; init_stack = Pending_coinbase.Stack.empty
      ; status = Mina_base.Transaction_status.Applied
      ; block_global_slot = global_slot
      }
  , second_pass_ledger )

(** Only [source.pending_coinbase_stack], [target.pending_coinbase_stack] and
    [connecting_ledger_left] are read out of this by the extraction path, so the
    remaining fields are left at their genesis values. *)
let build_input ~ledger ~global_slot =
  let state_body = Lazy.force protocol_state_body in
  let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
  let genesis_ledger_hash =
    Mina_ledger.Ledger.merkle_root ledger |> Frozen_ledger_hash.of_ledger_hash
  in
  let base = Mina_state.Snarked_ledger_state.genesis ~genesis_ledger_hash in
  let source_stack = Pending_coinbase.Stack.empty in
  let target_stack =
    Pending_coinbase.Stack.push_state state_body_hash global_slot source_stack
  in
  { base with
    source = { base.source with pending_coinbase_stack = source_stack }
  ; target = { base.target with pending_coinbase_stack = target_stack }
  ; connecting_ledger_left = genesis_ledger_hash
  }

let staged_ledger_hash_of ledger_hash =
  Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
    (Staged_ledger_hash.Aux_hash.of_bytes (String.make 32 '\000'))
    ledger_hash
    ( Pending_coinbase.create ~depth:constraint_constants.pending_coinbase_depth
        ()
    |> Or_error.ok_exn )

let sok_message =
  Sok_message.create
    ~fee:(Currency.Fee.of_nanomina_int_exn 1_000_000)
    ~prover:
      (Quickcheck.random_value ~seed:(`Deterministic "uptime-service-submitter")
         Signature_lib.Public_key.Compressed.gen )

let test_terminal_segment_is_stamped () =
  let global_slot = Mina_numbers.Global_slot_since_genesis.of_int 2 in
  let zkapp_command, ledger = generate_zkapp_command_and_ledger () in
  let witness, second_pass_ledger =
    build_witness ~ledger ~zkapp_command ~global_slot
  in
  let input = build_input ~ledger ~global_slot in
  (* The block's staged ledger hash is the ledger the block ends on, which is
     what makes the last segment of the last transaction the terminal one. *)
  let staged_ledger_hash =
    Mina_ledger.Ledger.merkle_root second_pass_ledger
    |> Frozen_ledger_hash.of_ledger_hash |> staged_ledger_hash_of
  in
  let sok_digest = Sok_message.digest sok_message in
  match
    Uptime_service.Uptime_snark_worker.extract_terminal_zk_segment
      ~signature_kind ~constraint_constants ~sok_digest ~witness ~input
      ~zkapp_command ~staged_ledger_hash
  with
  | Error e ->
      failwithf "could not extract the terminal zkApp segment: %s"
        (Error.to_string_hum e) ()
  | Ok (_witness, _spec, (statement : Transaction_snark.Statement.With_sok.t))
    ->
      if Sok_message.Digest.equal statement.sok_digest sok_digest then ()
      else if
        Sok_message.Digest.equal statement.sok_digest Sok_message.Digest.default
      then
        failwith
          "terminal segment statement still carries \
           Sok_message.Digest.default; a proof over it would attest to the \
           empty sok message and be rejected by delegation_verify"
      else failwith "terminal segment statement carries an unexpected digest"

let () =
  Alcotest.run "uptime_service"
    [ ( "zkapp terminal segment"
      , [ Alcotest.test_case
            "terminal segment statement carries the submitter's sok digest"
            `Quick test_terminal_segment_is_stamped
        ] )
    ]
