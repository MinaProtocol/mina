open Core_kernel
open Mina_base
open Mina_generators
open Mina_numbers
open Mina_transaction
open Staged_ledger

type apply =
     User_command.t Transaction.t_
  -> Ledger.Transaction_partially_applied.t Or_error.t

let gen_apply_and_txn : (apply * Application_state.txn) Quickcheck.Generator.t =
  let open Quickcheck.Generator in
  let open Let_syntax in
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let%bind txn, _, _, validating_ledger =
    User_command_generators.zkapp_command_with_ledger ()
  in
  let%map global_slot = Global_slot_since_genesis.gen in
  let current_state_view = Test_helpers.dummy_state_view ~global_slot () in
  let apply =
    Transaction_snark.Transaction_validator.apply_transaction_first_pass
      ~constraint_constants ~global_slot validating_ledger
      ~txn_state_view:current_state_view
  in
  (apply, txn)

let gen_application_state : Application_state.t Quickcheck.Generator.t =
  let open Application_state in
  let open Quickcheck.Generator in
  let open Let_syntax in
  let%bind valid_seq = return Sequence.empty in
  let%bind invalid = return [] in
  let%bind skipped_by_fee_payer = return Account_id.Map.empty in
  let%bind zkapp_space = Int.gen_incl 0 100 in
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
      match Application_state.try_applying_txn ~apply state txn with
      | Continue state'
        when state.total_space_remaining > 0
             && Option.equal Int.( = ) state.zkapp_space_remaining (Some 0) ->
          [%test_eq: int] (Map.length state'.skipped_by_fee_payer) 1
      | Continue state' when state.total_space_remaining > 0 ->
          [%test_eq: int] (Sequence.length state'.valid_seq) 1
      | Stop _ when state.total_space_remaining = 0 ->
          ()
      | Continue _ ->
          failwith "Application continues when it should have stopped."
      | Stop _ ->
          failwith "Application stopped when it should have continued." )

let gen_apply_and_signed_txn :
    (apply * Application_state.txn) Quickcheck.Generator.t =
  let open Quickcheck.Generator in
  let open Let_syntax in
  let constraint_constants =
    Genesis_constants.Constraint_constants.for_unit_tests
  in
  let%bind tx, _, _, ledger =
    User_command_generators.signed_command_with_ledger ()
  in
  let%map global_slot = Global_slot_since_genesis.gen in
  let current_state_view = Test_helpers.dummy_state_view ~global_slot () in
  let apply =
    Transaction_snark.Transaction_validator.apply_transaction_first_pass
      ~constraint_constants ~global_slot ledger
      ~txn_state_view:current_state_view
  in
  (apply, tx)

let gen_application_state_no_zkspace_remaining :
    Application_state.t Quickcheck.Generator.t =
  let open Application_state in
  let open Quickcheck.Generator in
  let open Let_syntax in
  let%bind valid_seq = return Sequence.empty in
  let%bind invalid = return [] in
  let%bind skipped_by_fee_payer = return Account_id.Map.empty in
  let zkapp_space_remaining = Some 0 in
  let%map total_space_remaining = Int.gen_incl 1 100 in
  { valid_seq
  ; invalid
  ; skipped_by_fee_payer
  ; zkapp_space_remaining
  ; total_space_remaining
  }

let zkapp_space_is_zero () =
  Quickcheck.test
    (Quickcheck.Generator.tuple2 gen_apply_and_signed_txn
       gen_application_state_no_zkspace_remaining )
    ~f:(fun ((apply, txn), state) ->
      match Application_state.try_applying_txn ~apply state txn with
      | Continue state' ->
          [%test_eq: int] (List.length state'.invalid) 1
      | _ ->
          failwith "Application stopped when it should have continued." )
