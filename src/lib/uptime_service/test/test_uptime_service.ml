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
open Mina_base
module Fixture = Transaction_snark_test_helpers.Zkapp_segment_fixture

(** Mirrors what the daemon hands the uptime snark worker: both sparse ledgers
    are snapshotted before the second pass runs, since the witness records the
    ledgers each pass starts from. *)
let build_witness (fixture : Fixture.t) =
  let accounts_referenced =
    Zkapp_command.accounts_referenced fixture.zkapp_command
  in
  let sparse_of l =
    Mina_ledger.Sparse_ledger.of_ledger_subset_exn l accounts_referenced
  in
  Transaction_witness.read_all_proofs_from_disk
    { Transaction_witness.transaction = Fixture.transaction fixture
    ; first_pass_ledger = sparse_of fixture.first_pass_ledger
    ; second_pass_ledger = sparse_of fixture.second_pass_ledger
    ; protocol_state_body = fixture.state_body
    ; init_stack = Pending_coinbase.Stack.empty
    ; status = Mina_base.Transaction_status.Applied
    ; block_global_slot = fixture.global_slot
    }

(** Only [source.pending_coinbase_stack], [target.pending_coinbase_stack] and
    [connecting_ledger_left] are read out of this by the extraction path, so the
    remaining fields are left at their genesis values. *)
let build_input (fixture : Fixture.t) =
  let state_body_hash =
    Mina_state.Protocol_state.Body.hash fixture.state_body
  in
  let genesis_ledger_hash =
    Mina_ledger.Ledger.merkle_root fixture.first_pass_ledger
    |> Frozen_ledger_hash.of_ledger_hash
  in
  let base = Mina_state.Snarked_ledger_state.genesis ~genesis_ledger_hash in
  let source_stack = Pending_coinbase.Stack.empty in
  let target_stack =
    Pending_coinbase.Stack.push_state state_body_hash fixture.global_slot
      source_stack
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
    ( Pending_coinbase.create
        ~depth:Fixture.constraint_constants.pending_coinbase_depth ()
    |> Or_error.ok_exn )

let sok_message =
  Sok_message.create
    ~fee:(Currency.Fee.of_nanomina_int_exn 1_000_000)
    ~prover:
      (Quickcheck.random_value ~seed:(`Deterministic "uptime-service-submitter")
         Signature_lib.Public_key.Compressed.gen )

let test_terminal_segment_is_stamped () =
  let fixture = Fixture.create ~seed:"uptime-service-zkapp-terminal-segment" in
  let witness = build_witness fixture in
  let input = build_input fixture in
  (* The block's staged ledger hash is the ledger the block ends on, which is
     what makes the last segment of the last transaction the terminal one. That
     is the root *after* the second pass, not the first-pass root: every
     first-pass segment statement carries the untouched second-pass ledger as
     its target, so selecting on the first-pass root would match the fee-payer
     segment and never exercise terminal selection at all. *)
  let first_pass_root =
    Mina_ledger.Ledger.merkle_root fixture.second_pass_ledger
  in
  let staged_ledger_hash =
    Fixture.finish_second_pass fixture
    |> Frozen_ledger_hash.of_ledger_hash |> staged_ledger_hash_of
  in
  (* Guards the point above: if this command's second pass happened to leave the
     root alone, the hash below would not distinguish the terminal segment from
     the fee-payer one and the assertion would prove nothing. *)
  if
    Ledger_hash.equal first_pass_root
      (Staged_ledger_hash.ledger_hash staged_ledger_hash)
  then
    failwith
      "the generated zkApp command's second pass left the ledger root \
       unchanged, so the terminal segment is not distinguishable by target \
       hash; pick a different generator seed"
  else () ;
  let sok_digest = Sok_message.digest sok_message in
  match
    Uptime_service.Uptime_snark_worker.extract_terminal_zk_segment
      ~signature_kind:Fixture.signature_kind
      ~constraint_constants:Fixture.constraint_constants ~sok_digest ~witness
      ~input ~zkapp_command:fixture.zkapp_command ~staged_ledger_hash
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
