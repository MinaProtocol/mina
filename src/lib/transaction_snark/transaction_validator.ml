open Base
open Mina_base
module Ledger = Mina_ledger.Ledger

let within_mask l ~f =
  let mask =
    Ledger.register_mask l (Ledger.Mask.create ~depth:(Ledger.depth l) ())
  in
  let r = f mask in
  if Result.is_ok r then Ledger.commit mask ;
  ignore
    (Ledger.unregister_mask_exn ~loc:Caml.__LOC__ mask : Ledger.unattached_mask) ;
  r

let apply_user_command ~constraint_constants ~txn_global_slot l uc =
  within_mask l ~f:(fun l' ->
      Result.map
        ~f:(fun applied_txn ->
          applied_txn.Ledger.Transaction_applied.Signed_command_applied.common
            .user_command
            .status )
        (Ledger.apply_user_command l' ~constraint_constants ~txn_global_slot uc) )

let apply_transactions' ~constraint_constants ~global_slot ~txn_state_view l t =
  O1trace.sync_thread "apply_transaction" (fun () ->
      within_mask l ~f:(fun l' ->
          Ledger.apply_transactions ~constraint_constants ~global_slot
            ~txn_state_view l' t ) )

let apply_transactions ~constraint_constants ~global_slot ~txn_state_view l txn
    =
  apply_transactions' l ~constraint_constants ~global_slot ~txn_state_view txn

let apply_transaction_first_pass ~constraint_constants ~global_slot
    ~txn_state_view l txn : Ledger.Transaction_partially_applied.t Or_error.t =
  O1trace.sync_thread "apply_transaction_first_pass" (fun () ->
      within_mask l ~f:(fun l' ->
          Ledger.apply_transaction_first_pass l' ~constraint_constants
            ~global_slot ~txn_state_view txn ) )

let%test_unit "invalid transactions do not dirty the ledger" =
  let open Core in
  let open Mina_numbers in
  let open Currency in
  let open Signature_lib in
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let ledger = Ledger.create_ephemeral ~depth:4 () in
  let sender_sk, receiver_sk =
    Quickcheck.Generator.generate ~size:0
      ~random:(Splittable_random.State.of_int 100)
      (Quickcheck.Generator.tuple2 Signature_lib.Private_key.gen
         Signature_lib.Private_key.gen )
  in
  let sender_pk =
    Public_key.compress (Public_key.of_private_key_exn sender_sk)
  in
  let sender_id = Account_id.create sender_pk Token_id.default in
  let sender_account : Account.t =
    Or_error.ok_exn
      (Account.create_timed sender_id
         (Balance.of_nanomina_int_exn 20)
         ~initial_minimum_balance:(Balance.of_nanomina_int_exn 20)
         ~cliff_time:Global_slot_since_genesis.one
         ~cliff_amount:(Amount.of_nanomina_int_exn 10)
         ~vesting_period:Global_slot_span.one
         ~vesting_increment:(Amount.of_nanomina_int_exn 1) )
  in
  let receiver_pk =
    Public_key.compress (Public_key.of_private_key_exn receiver_sk)
  in
  let receiver_id = Account_id.create receiver_pk Token_id.default in
  let receiver_account : Account.t =
    Account.create receiver_id (Balance.of_nanomina_int_exn 20)
  in
  let invalid_command =
    let payment : Payment_payload.t =
      { receiver_pk; amount = Amount.of_nanomina_int_exn 15 }
    in
    let payload =
      Signed_command_payload.create
        ~fee:(Fee.of_nanomina_int_exn 1)
        ~fee_payer_pk:sender_pk ~nonce:Account_nonce.zero ~valid_until:None
        ~memo:Signed_command_memo.dummy
        ~body:(Signed_command_payload.Body.Payment payment)
    in
    Option.value_exn
      (Signed_command.create_with_signature_checked
         (Signed_command.sign_payload sender_sk payload)
         sender_pk payload )
  in
  Ledger.create_new_account_exn ledger sender_id sender_account ;
  Ledger.create_new_account_exn ledger receiver_id receiver_account ;
  ( match
      apply_user_command ~constraint_constants
        ~txn_global_slot:Global_slot_since_genesis.one ledger invalid_command
    with
  | Ok _ ->
      failwith "successfully applied an invalid transaction"
  | Error err ->
      if
        String.equal (Error.to_string_hum err)
          "The source account requires a minimum balance"
      then ()
      else
        failwithf "transaction failed for an unexpected reason: %s\n"
          (Error.to_string_hum err) () ) ;
  let account_after_apply =
    Option.value_exn
      (Option.bind
         (Ledger.location_of_account ledger sender_id)
         ~f:(Ledger.get ledger) )
  in
  assert (Account_nonce.equal account_after_apply.nonce Account_nonce.zero)
