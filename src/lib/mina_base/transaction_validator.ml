open Base

let within_mask l ~f =
  let l' =
    Ledger.register_mask l (Ledger.Mask.create ~depth:(Ledger.depth l) ())
  in
  let r = f l' in
  if Result.is_ok r then Ledger.commit l' ;
  ignore
    (Ledger.unregister_mask_exn ~loc:Caml.__LOC__ l' : Ledger.unattached_mask) ;
  r

let apply_user_command ~constraint_constants ~txn_global_slot l uc =
  within_mask l ~f:(fun l' ->
      Result.map
        ~f:(fun applied_txn ->
          applied_txn.Ledger.Transaction_applied.Signed_command_applied.common
            .user_command
            .status )
        (Ledger.apply_user_command l' ~constraint_constants ~txn_global_slot uc) )

let apply_transaction ~constraint_constants ~txn_state_view l txn =
  within_mask l ~f:(fun l' ->
      Result.map ~f:Ledger.Transaction_applied.user_command_status
        (Ledger.apply_transaction l' ~constraint_constants ~txn_state_view txn) )

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
      (Account.create_timed sender_id (Balance.of_int 20)
         ~initial_minimum_balance:(Balance.of_int 20)
         ~cliff_time:(Global_slot.of_int 1) ~cliff_amount:(Amount.of_int 10)
         ~vesting_period:(Global_slot.of_int 1)
         ~vesting_increment:(Amount.of_int 1) )
  in
  let receiver_pk =
    Public_key.compress (Public_key.of_private_key_exn receiver_sk)
  in
  let receiver_id = Account_id.create receiver_pk Token_id.default in
  let receiver_account : Account.t =
    Account.create receiver_id (Balance.of_int 20)
  in
  let invalid_command =
    let payment : Payment_payload.t =
      { source_pk = sender_pk
      ; receiver_pk
      ; token_id = Token_id.default
      ; amount = Amount.of_int 15
      }
    in
    let payload =
      Signed_command_payload.create ~fee:(Fee.of_int 1)
        ~fee_token:Token_id.default ~fee_payer_pk:sender_pk
        ~nonce:(Account_nonce.of_int 0) ~valid_until:None
        ~memo:Signed_command_memo.dummy
        ~body:(Signed_command_payload.Body.Payment payment)
    in
    Signed_command.create_with_signature_checked
      (Signed_command.sign_payload sender_sk payload)
      sender_pk payload
    |> Option.value_exn
  in
  Ledger.create_new_account_exn ledger sender_id sender_account ;
  Ledger.create_new_account_exn ledger receiver_id receiver_account ;
  ( match
      apply_user_command ~constraint_constants
        ~txn_global_slot:(Global_slot.of_int 1) ledger invalid_command
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
    Ledger.location_of_account ledger sender_id
    |> Option.value_exn |> Ledger.get ledger |> Option.value_exn
  in
  assert (Account_nonce.equal account_after_apply.nonce (Account_nonce.of_int 0))
