(** A real ledger and a zkApp command that applies cleanly against it, with the
    transaction passes applied the way a block producer applies them.

    Shared by the tests in [snark_work_lib] and [uptime_service]: both need
    genuine zkApp segment witnesses, and both need the ledgers those witnesses
    are taken from. The generator defaults its verification key to
    [Pickles.Side_loaded.Verification_key.dummy] and nothing here proves
    anything, so no proving circuit is compiled. *)

open Core
open Mina_base

let constraint_constants =
  Genesis_constants.For_unit_tests.Constraint_constants.t

let genesis_constants = Genesis_constants.For_unit_tests.t

let signature_kind = Mina_signature_kind.Testnet

let protocol_state_body =
  lazy
    ( (Lazy.force Precomputed_values.for_unit_tests).protocol_state_with_hashes
        .data |> Mina_state.Protocol_state.body )

type t =
  { zkapp_command : Zkapp_command.t
  ; global_slot : Mina_numbers.Global_slot_since_genesis.t
  ; state_body : Mina_state.Protocol_state.Body.Value.t
  ; first_pass_ledger : Mina_ledger.Ledger.t
        (** The generated ledger, untouched: the ledger the first pass starts
            from. *)
  ; second_pass_ledger : Mina_ledger.Ledger.t
        (** A mask over [first_pass_ledger] carrying the first pass only, so
            the ledger the second pass starts from until
            [finish_second_pass] is called. *)
  ; partially_applied : Mina_ledger.Ledger.Transaction_partially_applied.t
  }

let transaction (t : t) : Mina_transaction.Transaction.t =
  Command (Zkapp_command t.zkapp_command)

let create ~seed =
  let global_slot = Mina_numbers.Global_slot_since_genesis.of_int 2 in
  let user_command, _fee_payer_keypair, _keymap, first_pass_ledger =
    Quickcheck.random_value ~seed:(`Deterministic seed)
      (Mina_generators.User_command_generators.zkapp_command_with_ledger
         ~genesis_constants ~constraint_constants () )
  in
  let zkapp_command =
    match user_command with
    | User_command.Zkapp_command zkapp_command ->
        Zkapp_command.Valid.forget zkapp_command
    | User_command.Signed_command _ ->
        failwith "generator produced a signed command, expected a zkApp command"
  in
  let state_body = Lazy.force protocol_state_body in
  let second_pass_ledger =
    Mina_ledger.Ledger.register_mask first_pass_ledger
      (Mina_ledger.Ledger.Mask.create
         ~depth:(Mina_ledger.Ledger.depth first_pass_ledger)
         () )
  in
  let partially_applied =
    Mina_ledger.Ledger.apply_transaction_first_pass ~signature_kind
      ~constraint_constants ~global_slot
      ~txn_state_view:(Mina_state.Protocol_state.Body.view state_body)
      second_pass_ledger
      (Mina_transaction.Transaction.Command
         (User_command.Zkapp_command zkapp_command) )
    |> Or_error.ok_exn
  in
  { zkapp_command
  ; global_slot
  ; state_body
  ; first_pass_ledger
  ; second_pass_ledger
  ; partially_applied
  }

(** Apply the second pass to [second_pass_ledger], leaving it on the ledger the
    block ends on, and return that ledger's root.

    Any sparse-ledger witness of the second pass has to be taken *before*
    calling this, since the witness records the ledger that pass starts from.
    [Staged_ledger] snapshots it in the same order. *)
let finish_second_pass (t : t) =
  let (_ : Mina_transaction_logic.Transaction_applied.t) =
    Mina_ledger.Ledger.apply_transaction_second_pass t.second_pass_ledger
      t.partially_applied
    |> Or_error.ok_exn
  in
  Mina_ledger.Ledger.merkle_root t.second_pass_ledger
