open Core_kernel
open Currency
open Mina_base
open Mina_base_test_helpers
open Mina_ledger_test_helpers
open Signature_lib
open Transaction_logic_tests
open Helpers

(* Generate a delegator, a validator, and fee for the tx *)
let gen_delegation_scenario =
  let open Quickcheck.Generator.Let_syntax in
  let%bind delegator =
    Test_account.gen_constrained_balance
      ~min:(Balance.of_mina_int_exn 5)
      ~max:(Balance.of_mina_int_exn 1_000_000)
      ()
  in
  let%bind validator =
    Test_account.gen_constrained_balance
      ~min:(Balance.of_nanomina_int_exn 1)
      ~max:(Balance.of_mina_int_exn 1_000_000)
      ()
  in
  let%map fee = Fee.gen_incl Fee.one (Fee.of_mina_int_exn 1) in
  (delegator, validator, fee)

let set_delegate_in_ledger ledger pk new_delegate =
  let acc_id = Account_id.create pk Token_id.default in
  let location = Option.value_exn (Ledger.location_of_account ledger acc_id) in
  let account = Option.value_exn (Ledger.get ledger location) in
  Ledger.set ledger location { account with delegate = new_delegate }

(* New accounts start with delegate = None. A delegation tx
   from such an account points its delegate at a real validator. *)
let opt_in_from_default_unstaked () =
  Quickcheck.test ~trials:100 gen_delegation_scenario
    ~f:(fun (delegator, validator, fee) ->
      let ledger =
        Ledger_helpers.ledger_of_accounts [ delegator; validator ]
        |> Or_error.ok_exn
      in
      apply_txn_exn ledger
        (signed_command ~sender:delegator ~fee
           (delegation_body ~new_delegate:validator.pk) ) ;
      assert (
        Option.equal Public_key.Compressed.equal
          (get_account_exn ledger delegator.pk).delegate (Some validator.pk) ) )

(* An account that is currently delegating can opt out by delegating to the
   empty public key. *)
let opt_out_via_empty_delegation () =
  Quickcheck.test ~trials:100 gen_delegation_scenario
    ~f:(fun (delegator, validator, fee) ->
      let ledger =
        Ledger_helpers.ledger_of_accounts [ delegator; validator ]
        |> Or_error.ok_exn
      in
      apply_txn_exn ledger
        (signed_command ~sender:delegator ~fee
           (delegation_body ~new_delegate:validator.pk) ) ;
      (* Refresh nonce/balance after the first txn before submitting the next. *)
      let after = get_account_exn ledger delegator.pk in
      let sender =
        { delegator with nonce = after.nonce; balance = after.balance }
      in
      apply_txn_exn ledger
        (signed_command ~sender ~fee
           (delegation_body ~new_delegate:Public_key.Compressed.empty) ) ;
      assert (Option.is_none (get_account_exn ledger delegator.pk).delegate) )

(* The migration path: an account that was auto-self-delegated under the
   pre-unstaking semantics ([delegate = Some self_pk]) can opt out by
   delegating to the empty public key, just like accounts created after the
   transition. *)
let opt_out_from_legacy_self_delegated () =
  Quickcheck.test ~trials:100 gen_delegation_scenario
    ~f:(fun (delegator, _validator, fee) ->
      let ledger =
        Ledger_helpers.ledger_of_accounts [ delegator ] |> Or_error.ok_exn
      in
      set_delegate_in_ledger ledger delegator.pk (Some delegator.pk) ;
      apply_txn_exn ledger
        (signed_command ~sender:delegator ~fee
           (delegation_body ~new_delegate:Public_key.Compressed.empty) ) ;
      assert (Option.is_none (get_account_exn ledger delegator.pk).delegate) )

(* Stake_delegation to a real public key that isn't in the ledger applies as a
   failed user command: the fee is debited but the delegate field is left
   untouched (in particular, NOT set to the unknown pk). This is the asymmetry
   that distinguishes a non-existent delegatee from the [empty_pk] unstaking
   case. *)
let delegating_to_unknown_pk_fails () =
  Quickcheck.test ~trials:100 gen_delegation_scenario
    ~f:(fun (delegator, unknown_validator, fee) ->
      (* unknown_validator is generated but NOT inserted into the ledger. *)
      let ledger =
        Ledger_helpers.ledger_of_accounts [ delegator ] |> Or_error.ok_exn
      in
      apply_txn_exn ledger
        (signed_command ~sender:delegator ~fee
           (delegation_body ~new_delegate:unknown_validator.pk) ) ;
      assert (Option.is_none (get_account_exn ledger delegator.pk).delegate) )
