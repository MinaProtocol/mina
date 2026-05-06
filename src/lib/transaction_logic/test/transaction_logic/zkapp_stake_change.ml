(** Unit tests for [Transaction_applied.stake_change] on zkApp transactions,
    against the case spine in [docs/unstaking-stake-change.md] §
    "Test case spine".

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

let set_delegate_update target =
  { Account_update.Update.noop with
    delegate = Zkapp_basic.Set_or_keep.Set target.Test_account.pk
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
    ~f:(fun (fp, validator, fee) ->
      let ledger = ledger_of [ fp ] in
      set_delegate ledger fp.pk (Some validator) ;
      let txn = zkapp_txn ~fee_payer:fp ~fee [ fp ] in
      check ~name:"z1 fee_payer staked, no other updates"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z2 *)
let z2_fee_payer_only_unstaked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 (gen_account ()) fee_gen)
    ~f:(fun (fp, fee) ->
      let ledger = ledger_of [ fp ] in
      let txn = zkapp_txn ~fee_payer:fp ~fee [ fp ] in
      check ~name:"z2 fee_payer unstaked, no other updates"
        ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Per-account stake transitions on a non-fp target.                *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z3 — per-account shape (1,1). fp staked,
   t staked, counter unstaked. Simple_txn(t, counter, A) debits t by
   A. Sum: −fee + (−A) + 0 = −(fee + A). *)
let z3_balance_change_staked_target () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ())
        (gen_account ~min_balance:0 ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fp, t, counter, (validator, fee)) ->
      let amount = Amount.of_mina_int_exn 1 in
      let ledger = ledger_of [ fp; t; counter ] in
      set_delegate ledger fp.pk (Some validator) ;
      set_delegate ledger t.pk (Some validator) ;
      let zk = Simple_txn.make ~sender:t ~receiver:counter amount in
      let txn =
        zkapp_txn ~fee_payer:fp ~fee ~transactions:[ zk ] [ fp; t; counter ]
      in
      let expected = add_signed (neg (fee_amt fee)) (neg amount) in
      check ~name:"z3 balance change on staked target" ~expected
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z4 — per-account shape (0,1). Opt-in: t's
   delegate goes None → Some validator. balance unchanged so
   balance'(t) = balance(t). Sum: −fee + balance(t). *)
let z4_opt_in_delegate () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fp, t, validator_account, (fp_validator, fee)) ->
      let ledger = ledger_of [ fp; t; validator_account ] in
      set_delegate ledger fp.pk (Some fp_validator) ;
      let zk =
        Alter_account.make ~account:t (set_delegate_update validator_account)
      in
      let txn =
        zkapp_txn ~fee_payer:fp ~fee ~transactions:[ zk ]
          [ fp; t; validator_account ]
      in
      let expected =
        add_signed (neg (fee_amt fee)) (plus (balance_amt t.balance))
      in
      check ~name:"z4 opt-in (delegate None → Some)" ~expected
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z5 — per-account shape (1,0). Opt-out: t's
   delegate goes Some → empty_pk. balance unchanged. Sum: −fee − balance(t). *)
let z5_opt_out_delegate () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3 (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fp, t, (validator, fee)) ->
      let ledger = ledger_of [ fp; t ] in
      set_delegate ledger fp.pk (Some validator) ;
      set_delegate ledger t.pk (Some validator) ;
      let zk = Alter_account.make ~account:t set_delegate_to_empty in
      let txn = zkapp_txn ~fee_payer:fp ~fee ~transactions:[ zk ] [ fp; t ] in
      let expected =
        add_signed (neg (fee_amt fee)) (neg (balance_amt t.balance))
      in
      check ~name:"z5 opt-out (delegate Some → empty_pk)" ~expected
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Multi-update aggregation.                                        *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z6 — telescoping. Two updates on the same
   target t: opt-in (None → v1) then opt-out (v1 → empty_pk). The
   intermediate state is staked, but the *final* state is unstaked.
   Per-account contribution must reflect only post − pre = 0. Sum: −fee. *)
let z6_telescoping_same_target () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fp, t, intermediate_validator, (fp_validator, fee)) ->
      let ledger = ledger_of [ fp; t; intermediate_validator ] in
      set_delegate ledger fp.pk (Some fp_validator) ;
      let zk_in =
        Alter_account.make ~account:t
          (set_delegate_update intermediate_validator)
      in
      let zk_out = Alter_account.make ~account:t set_delegate_to_empty in
      let txn =
        zkapp_txn ~fee_payer:fp ~fee ~transactions:[ zk_in; zk_out ]
          [ fp; t; intermediate_validator ]
      in
      check ~name:"z6 telescoping on same target (None → v1 → empty)"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* zkapp_stake_change_row_z7 — distinct targets, distinct contributions.
   t1 unstaked → opt-in (Δstake_t1 = +balance(t1));
   t2 staked   → opt-out (Δstake_t2 = −balance(t2)).
   Sum: −fee + balance(t1) − balance(t2). *)
let z7_distinct_targets () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3
        (tuple3 (gen_account ()) (gen_account ()) (gen_account ()))
        (gen_account ())
        (tuple3 Public_key.Compressed.gen Public_key.Compressed.gen fee_gen))
    ~f:(fun ((fp, t1, t2), validator_account, (fp_v, t2_v, fee)) ->
      let ledger = ledger_of [ fp; t1; t2; validator_account ] in
      set_delegate ledger fp.pk (Some fp_v) ;
      set_delegate ledger t2.pk (Some t2_v) ;
      let zk_t1 =
        Alter_account.make ~account:t1 (set_delegate_update validator_account)
      in
      let zk_t2 = Alter_account.make ~account:t2 set_delegate_to_empty in
      let txn =
        zkapp_txn ~fee_payer:fp ~fee ~transactions:[ zk_t1; zk_t2 ]
          [ fp; t1; t2; validator_account ]
      in
      let expected =
        add_signed
          (add_signed (neg (fee_amt fee)) (plus (balance_amt t1.balance)))
          (neg (balance_amt t2.balance))
      in
      check ~name:"z7 sum across distinct targets" ~expected
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Failure path.                                                    *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z8 — second-pass check fails: t's
   set_delegate permission is Impossible, so the delegate update is
   rejected and the second pass rolls back. Only the fee_payer's debit
   sticks. Sum: −fee·fp_staked. *)
let z8_second_pass_fail () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple4 (gen_account ()) (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fp, t, validator_account, (fp_v, fee)) ->
      let ledger = ledger_of [ fp; t; validator_account ] in
      set_delegate ledger fp.pk (Some fp_v) ;
      set_permissions ledger t.pk
        { Permissions.user_default with
          set_delegate = Permissions.Auth_required.Impossible
        } ;
      let zk =
        Alter_account.make ~account:t (set_delegate_update validator_account)
      in
      let txn =
        zkapp_txn ~fee_payer:fp ~fee ~transactions:[ zk ]
          [ fp; t; validator_account ]
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
   Constructed as Txn_tree(token_owner, children=[Single(t, +A)])
   where t is on the custom token. The t account contributes 0 to
   stake_change (excluded from A(tx) by the default-token
   restriction; equivalently is_staked(t) = 0 since non-default-token
   delegates must be empty). Sum: −fee·fp_staked. *)
let z9_non_default_token_balance_change () =
  Quickcheck.test ~trials
    (let open Quickcheck.Generator.Let_syntax in
    let%bind token_owner, custom_token = gen_custom_token_owner in
    let%bind t =
      Test_account.with_token_id ~gen:(gen_account ()) custom_token
    in
    let%map fp_validator = Public_key.Compressed.gen and fee = fee_gen in
    (token_owner, t, fp_validator, fee))
    ~f:(fun (token_owner, t, fp_validator, fee) ->
      let ledger = ledger_of [ token_owner; t ] in
      set_delegate ledger token_owner.pk (Some fp_validator) ;
      let zk =
        Txn_tree.make ~account:token_owner
          ~children:
            [ ( Single.make ~account:t
                  Amount.Signed.(of_unsigned (Amount.of_mina_int_exn 1))
                :> transaction )
            ]
          Account_update.Update.noop
      in
      let txn =
        zkapp_txn ~fee_payer:token_owner ~fee ~transactions:[ zk ]
          [ token_owner; t ]
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
    let%bind t =
      Test_account.with_token_id ~gen:(gen_account ()) custom_token
    in
    let%bind new_delegate = gen_account () in
    let%map fp_validator = Public_key.Compressed.gen and fee = fee_gen in
    (token_owner, t, new_delegate, fp_validator, fee))
    ~f:(fun (token_owner, t, new_delegate, fp_validator, fee) ->
      let ledger = ledger_of [ token_owner; t; new_delegate ] in
      set_delegate ledger token_owner.pk (Some fp_validator) ;
      let zk =
        Txn_tree.make ~account:token_owner
          ~children:
            [ ( Alter_account.make ~account:t (set_delegate_update new_delegate)
                :> transaction )
            ]
          Account_update.Update.noop
      in
      let txn =
        zkapp_txn ~fee_payer:token_owner ~fee ~transactions:[ zk ]
          [ token_owner; t; new_delegate ]
      in
      check ~name:"z10 non-default-token delegate Set"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Field-set restriction.                                           *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z11 — Alter_account on default-token target
   that changes only [permissions]. balance and delegate unchanged →
   per-account contribution is 0. Sum: −fee·fp_staked. *)
let z11_default_token_permissions_only () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3 (gen_account ()) (gen_account ())
        (tuple2 Public_key.Compressed.gen fee_gen))
    ~f:(fun (fp, t, (fp_v, fee)) ->
      let ledger = ledger_of [ fp; t ] in
      set_delegate ledger fp.pk (Some fp_v) ;
      let new_perms =
        { Permissions.user_default with
          set_zkapp_uri = Permissions.Auth_required.Proof
        }
      in
      let state_update =
        { Account_update.Update.noop with
          permissions = Zkapp_basic.Set_or_keep.Set new_perms
        }
      in
      let zk = Alter_account.make ~account:t state_update in
      let txn = zkapp_txn ~fee_payer:fp ~fee ~transactions:[ zk ] [ fp; t ] in
      check ~name:"z11 permissions-only update on default-token target"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )
