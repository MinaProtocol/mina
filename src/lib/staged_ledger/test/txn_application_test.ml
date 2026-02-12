open Core_kernel
open Mina_base
open Mina_generators
open Mina_numbers
open Mina_transaction
module Application_state = Staged_ledger.For_tests.Application_state

type apply =
     User_command.t Transaction.t_
  -> Staged_ledger.Ledger.Transaction_partially_applied.t Or_error.t

let gen_apply_and_txn : (apply * User_command.Valid.t) Quickcheck.Generator.t =
  let open Quickcheck.Generator in
  let open Let_syntax in
  let constraint_constants =
    Genesis_constants.For_unit_tests.Constraint_constants.t
  in
  let%bind txn, _, _, validating_ledger =
    User_command_generators.zkapp_command_with_ledger ~constraint_constants
      ~genesis_constants:Genesis_constants.For_unit_tests.t ()
  in
  let%map global_slot = Global_slot_since_genesis.gen in
  let current_state_view =
    Staged_ledger.Test_helpers.dummy_state_view ~global_slot ()
  in
  let apply =
    Transaction_snark.Transaction_validator.apply_transaction_first_pass
      ~constraint_constants ~global_slot validating_ledger
      ~txn_state_view:current_state_view
      ~signature_kind:Mina_signature_kind.Testnet
  in
  (apply, txn)

let gen_application_state :
    User_command.Valid.t Application_state.t Quickcheck.Generator.t =
  let open Application_state in
  let open Quickcheck.Generator in
  let open Let_syntax in
  let%bind valid_seq = return Sequence.empty in
  let%bind invalid = return [] in
  let%bind skipped_by_fee_payer = return Account_id.Map.empty in
  let%bind zkapp_space = Int.gen_incl (-1) 100 in
  let zkapp_space_remaining = Option.some_if (zkapp_space >= 0) zkapp_space in
  let%map total_space_remaining = Int.gen_incl 0 100 in
  { valid_seq
  ; invalid
  ; skipped_by_fee_payer
  ; zkapp_space_remaining
  ; total_space_remaining
  }

let apply_against_non_empty_scan_state () =
  Quickcheck.test
    (Quickcheck.Generator.tuple2 gen_apply_and_txn gen_application_state)
    ~f:(fun ((apply, txn), state) ->
      match
        Application_state.Valid_user_command.try_applying_txn ~apply state txn
      with
      | Continue state' when state.total_space_remaining > 0 ->
          [%test_pred: int]
            (fun delta -> delta = 0 || delta = 1)
            (state.total_space_remaining - state'.total_space_remaining)
      | Stop _ when state.total_space_remaining = 0 ->
          ()
      | Continue _ ->
          failwith "Application continues when it should have stopped."
      | Stop _ ->
          failwith "Application stopped when it should have continued." )
