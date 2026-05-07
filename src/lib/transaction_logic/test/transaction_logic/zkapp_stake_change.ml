(** Unit tests for [Transaction_applied.stake_change] on zkApp transactions,
    against the representative test cases in
    [docs/unstaking-stake-change.md] § "Representative test cases".

    Drives the same [apply_and_snapshot] / [measure_stake_change] pipeline
    as the non-zkApp [stake_change.ml] — these helpers operate on
    [Mina_transaction.Transaction.t], so we just feed in a
    [Command (Zkapp_command zc)] built via [Zkapp_cmd_builder]. *)

open Core_kernel
open Currency
open Mina_base
open Mina_base_test_helpers
open Mina_ledger_test_helpers
open Signature_lib
open Transaction_logic_tests
open Helpers
open Stake_change_helpers
open Zkapp_cmd_builder
module Transaction = Mina_transaction.Transaction

let fee_gen = Fee.gen_incl Fee.one (Fee.of_mina_int_exn 1)

let zkapp_txn ~fee_payer ~fee ?(transactions = []) accounts : Transaction.t =
  let cmd =
    zkapp_cmd
      ~noncemap:(Ledger_helpers.noncemap accounts)
      ~fee:(fee_payer.Test_account.pk, fee)
      (transactions :> transaction list)
  in
  Command (User_command.Zkapp_command cmd)

let set_delegate_update new_delegate =
  { Account_update.Update.noop with
    delegate = Zkapp_basic.Set_or_keep.Set new_delegate.Test_account.pk
  }

let set_delegate_to_empty =
  { Account_update.Update.noop with
    delegate = Zkapp_basic.Set_or_keep.Set Public_key.Compressed.empty
  }

(* ---------------------------------------------------------------- *)
(* Baseline: fee_payer-only zkApp txs (empty call forest).          *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z1 *)
let z1_fee_payer_only_staked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3 (gen_account ()) Public_key.Compressed.gen fee_gen)
    ~f:(fun (fee_payer, validator, fee) ->
      let ledger = ledger_of [ fee_payer ] in
      set_delegate ledger fee_payer.pk (Some validator) ;
      let txn = zkapp_txn ~fee_payer ~fee [ fee_payer ] in
      check ~name:"z1 fee_payer staked, no other updates"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z2 *)
let z2_fee_payer_only_unstaked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 (gen_account ()) fee_gen)
    ~f:(fun (fee_payer, fee) ->
      let ledger = ledger_of [ fee_payer ] in
      let txn = zkapp_txn ~fee_payer ~fee [ fee_payer ] in
      check ~name:"z2 fee_payer unstaked, no other updates"
        ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Per-account stake transitions on a non-fp target.                *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z3 — staked → staked balance change on a
   non-fp target. fee_payer staked, [staked_target] staked,
   [unstaked_counterparty] unstaked. Simple_txn(staked_target,
   unstaked_counterparty, amount) debits the staked target by [amount].
   Sum: −fee + (−amount) + 0 = −(fee + amount). *)
let z3_balance_change_staked_target () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ())
        (gen_account ~min_balance:0 ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fee_payer, staked_target, unstaked_counterparty, (validator, fee)) ->
      let amount = Amount.of_mina_int_exn 1 in
      let ledger =
        ledger_of [ fee_payer; staked_target; unstaked_counterparty ]
      in
      set_delegate ledger fee_payer.pk (Some validator) ;
      set_delegate ledger staked_target.pk (Some validator) ;
      let payment_update =
        Simple_txn.make ~sender:staked_target ~receiver:unstaked_counterparty
          amount
      in
      let txn =
        zkapp_txn ~fee_payer ~fee ~transactions:[ payment_update ]
          [ fee_payer; staked_target; unstaked_counterparty ]
      in
      let expected = add_signed (neg (fee_amt fee)) (neg amount) in
      check ~name:"z3 balance change on staked target" ~expected
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z4 — opt-in (unstaked → staked).
   [opt_in_target]'s delegate goes None → Some [new_delegate]. balance
   unchanged so balance'(opt_in_target) = balance(opt_in_target). Sum:
   −fee + balance(opt_in_target). *)
let z4_opt_in_delegate () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fee_payer, opt_in_target, new_delegate, (fee_payer_validator, fee)) ->
      let ledger = ledger_of [ fee_payer; opt_in_target; new_delegate ] in
      set_delegate ledger fee_payer.pk (Some fee_payer_validator) ;
      let opt_in_update =
        Alter_account.make ~account:opt_in_target
          (set_delegate_update new_delegate)
      in
      let txn =
        zkapp_txn ~fee_payer ~fee ~transactions:[ opt_in_update ]
          [ fee_payer; opt_in_target; new_delegate ]
      in
      let expected =
        add_signed
          (neg (fee_amt fee))
          (plus (balance_amt opt_in_target.balance))
      in
      check ~name:"z4 opt-in (delegate None → Some)" ~expected
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z5 — opt-out (staked → unstaked).
   [opt_out_target]'s delegate goes Some → empty_pk. balance
   unchanged. Sum: −fee − balance(opt_out_target). *)
let z5_opt_out_delegate () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3 (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fee_payer, opt_out_target, (validator, fee)) ->
      let ledger = ledger_of [ fee_payer; opt_out_target ] in
      set_delegate ledger fee_payer.pk (Some validator) ;
      set_delegate ledger opt_out_target.pk (Some validator) ;
      let opt_out_update =
        Alter_account.make ~account:opt_out_target set_delegate_to_empty
      in
      let txn =
        zkapp_txn ~fee_payer ~fee ~transactions:[ opt_out_update ]
          [ fee_payer; opt_out_target ]
      in
      let expected =
        add_signed
          (neg (fee_amt fee))
          (neg (balance_amt opt_out_target.balance))
      in
      check ~name:"z5 opt-out (delegate Some → empty_pk)" ~expected
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Multi-update aggregation.                                        *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z6 — telescoping. Two updates on the same
   [target]: opt-in (None → [intermediate_validator]) then opt-out
   ([intermediate_validator] → empty_pk). The intermediate state is
   staked, but the *final* state is unstaked. Per-account contribution
   must reflect only post − pre = 0. Sum: −fee. *)
let z6_telescoping_same_target () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun ( fee_payer
            , target
            , intermediate_validator
            , (fee_payer_validator, fee) ) ->
      let ledger = ledger_of [ fee_payer; target; intermediate_validator ] in
      set_delegate ledger fee_payer.pk (Some fee_payer_validator) ;
      let opt_in_update =
        Alter_account.make ~account:target
          (set_delegate_update intermediate_validator)
      in
      let opt_out_update =
        Alter_account.make ~account:target set_delegate_to_empty
      in
      let txn =
        zkapp_txn ~fee_payer ~fee
          ~transactions:[ opt_in_update; opt_out_update ]
          [ fee_payer; target; intermediate_validator ]
      in
      check ~name:"z6 telescoping on same target (None → v1 → empty)"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z7 — distinct targets, distinct contributions.
   [opt_in_target] unstaked → opt-in (Δstake = +balance(opt_in_target));
   [opt_out_target] staked → opt-out (Δstake = −balance(opt_out_target)).
   Sum: −fee + balance(opt_in_target) − balance(opt_out_target). *)
let z7_distinct_targets () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3
        (tuple3 (gen_account ()) (gen_account ()) (gen_account ()))
        (gen_account ())
        (tuple3 Public_key.Compressed.gen Public_key.Compressed.gen fee_gen))
    ~f:(fun ( (fee_payer, opt_in_target, opt_out_target)
            , new_delegate
            , (fee_payer_validator, opt_out_target_validator, fee) ) ->
      let ledger =
        ledger_of [ fee_payer; opt_in_target; opt_out_target; new_delegate ]
      in
      set_delegate ledger fee_payer.pk (Some fee_payer_validator) ;
      set_delegate ledger opt_out_target.pk (Some opt_out_target_validator) ;
      let opt_in_update =
        Alter_account.make ~account:opt_in_target
          (set_delegate_update new_delegate)
      in
      let opt_out_update =
        Alter_account.make ~account:opt_out_target set_delegate_to_empty
      in
      let txn =
        zkapp_txn ~fee_payer ~fee
          ~transactions:[ opt_in_update; opt_out_update ]
          [ fee_payer; opt_in_target; opt_out_target; new_delegate ]
      in
      let expected =
        add_signed
          (add_signed
             (neg (fee_amt fee))
             (plus (balance_amt opt_in_target.balance)) )
          (neg (balance_amt opt_out_target.balance))
      in
      check ~name:"z7 sum across distinct targets" ~expected
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Failure path.                                                    *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z8 — second-pass check fails:
   [rejecting_target]'s set_delegate permission is Impossible, so the
   delegate update is rejected and the second pass rolls back. Only
   the fee_payer's debit sticks. Sum: −fee·fp_staked. *)
let z8_second_pass_fail () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun ( fee_payer
            , rejecting_target
            , attempted_delegate
            , (fee_payer_validator, fee) ) ->
      let ledger =
        ledger_of [ fee_payer; rejecting_target; attempted_delegate ]
      in
      set_delegate ledger fee_payer.pk (Some fee_payer_validator) ;
      set_permissions ledger rejecting_target.pk
        { Permissions.user_default with
          set_delegate = Permissions.Auth_required.Impossible
        } ;
      let rejected_delegate_update =
        Alter_account.make ~account:rejecting_target
          (set_delegate_update attempted_delegate)
      in
      let txn =
        zkapp_txn ~fee_payer ~fee
          ~transactions:[ rejected_delegate_update ]
          [ fee_payer; rejecting_target; attempted_delegate ]
      in
      check ~name:"z8 second-pass failure → fee_payer only"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Default-token restriction (most distant from signed_command).    *)
(* ---------------------------------------------------------------- *)

(* Sufficiently-funded owner of a custom token, for non-default-token
   tests. [Test_account.gen_custom_token] uses unconstrained
   [Balance.gen], which can produce balances < fee. *)
let gen_custom_token_owner =
  let open Quickcheck.Generator.Let_syntax in
  let%map owner = gen_account () in
  let custom_token =
    Account_id.derive_token_id ~owner:(Test_account.account_id owner)
  in
  (owner, custom_token)

(* zkapp_stake_change_row_z9 — non-default-token balance change.
   Constructed as Txn_tree(token_owner, children=[Single(custom_token_account, +A)]).
   The custom-token account contributes 0 to stake_change (excluded
   from A(tx) by the default-token restriction; equivalently
   is_staked = 0 since non-default-token delegates must be empty).
   Sum: −fee·fp_staked. *)
let z9_non_default_token_balance_change () =
  Quickcheck.test ~trials
    (let open Quickcheck.Generator.Let_syntax in
    let%bind token_owner, custom_token = gen_custom_token_owner in
    let%bind custom_token_account =
      Test_account.with_token_id ~gen:(gen_account ()) custom_token
    in
    let%map fee_payer_validator = Public_key.Compressed.gen and fee = fee_gen in
    (token_owner, custom_token_account, fee_payer_validator, fee))
    ~f:(fun (token_owner, custom_token_account, fee_payer_validator, fee) ->
      let ledger = ledger_of [ token_owner; custom_token_account ] in
      set_delegate ledger token_owner.pk (Some fee_payer_validator) ;
      let custom_token_balance_change =
        Txn_tree.make ~account:token_owner
          ~children:
            [ ( Single.make ~account:custom_token_account
                  Amount.Signed.(of_unsigned (Amount.of_mina_int_exn 1))
                :> transaction )
            ]
          Account_update.Update.noop
      in
      let txn =
        zkapp_txn ~fee_payer:token_owner ~fee
          ~transactions:[ custom_token_balance_change ]
          [ token_owner; custom_token_account ]
      in
      check ~name:"z9 non-default-token balance change"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z10 — non-default-token delegate Set
   attempt. Mirrors the existing zkapp_logic.ml test "Delegate cannot
   be set on account with non-default token", which fails with
   Update_not_permitted_delegate. Failure rolls back the second pass,
   so only fee_payer commits. Sum: −fee·fp_staked. *)
let z10_non_default_token_delegate_set () =
  Quickcheck.test ~trials
    (let open Quickcheck.Generator.Let_syntax in
    let%bind token_owner, custom_token = gen_custom_token_owner in
    let%bind custom_token_account =
      Test_account.with_token_id ~gen:(gen_account ()) custom_token
    in
    let%bind attempted_delegate = gen_account () in
    let%map fee_payer_validator = Public_key.Compressed.gen and fee = fee_gen in
    ( token_owner
    , custom_token_account
    , attempted_delegate
    , fee_payer_validator
    , fee ))
    ~f:(fun ( token_owner
            , custom_token_account
            , attempted_delegate
            , fee_payer_validator
            , fee ) ->
      let ledger =
        ledger_of [ token_owner; custom_token_account; attempted_delegate ]
      in
      set_delegate ledger token_owner.pk (Some fee_payer_validator) ;
      let rejected_delegate_set =
        Txn_tree.make ~account:token_owner
          ~children:
            [ ( Alter_account.make ~account:custom_token_account
                  (set_delegate_update attempted_delegate)
                :> transaction )
            ]
          Account_update.Update.noop
      in
      let txn =
        zkapp_txn ~fee_payer:token_owner ~fee
          ~transactions:[ rejected_delegate_set ]
          [ token_owner; custom_token_account; attempted_delegate ]
      in
      check ~name:"z10 non-default-token delegate Set"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Field-set restriction.                                           *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z11 — Alter_account on default-token
   [target] that changes only [permissions]. balance and delegate
   unchanged → per-account contribution is 0. Sum: −fee·fp_staked. *)
let z11_default_token_permissions_only () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3 (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fee_payer, target, (fee_payer_validator, fee)) ->
      let ledger = ledger_of [ fee_payer; target ] in
      set_delegate ledger fee_payer.pk (Some fee_payer_validator) ;
      let new_permissions =
        { Permissions.user_default with
          set_zkapp_uri = Permissions.Auth_required.Proof
        }
      in
      let permissions_only_state_update =
        { Account_update.Update.noop with
          permissions = Zkapp_basic.Set_or_keep.Set new_permissions
        }
      in
      let permissions_update =
        Alter_account.make ~account:target permissions_only_state_update
      in
      let txn =
        zkapp_txn ~fee_payer ~fee ~transactions:[ permissions_update ]
          [ fee_payer; target ]
      in
      check ~name:"z11 permissions-only update on default-token target"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )
