(** Unit tests for [Transaction_applied.stake_change] against the coverage
    table in [docs/unstaking-stake-change.md].

    For each row we set up a minimal ledger with the relevant pre-state
    (staked/unstaked fee_payer, staked/unstaked receiver, delegate targets),
    apply the transaction, and assert the computed stake_change equals the
    collapsed formula in the table's last column. *)

open Core_kernel
open Currency
open Mina_base
open Mina_base_test_helpers
open Mina_ledger_test_helpers
open Signature_lib
open Transaction_logic_tests
open Protocol_config_examples
open Helpers
module Sparse_ledger = Mina_ledger.Sparse_ledger
module Transaction = Mina_transaction.Transaction
module Transaction_applied = Mina_transaction_logic.Transaction_applied

(* ---------------------------------------------------------------- *)
(* Stake-change-specific helpers.                                   *)
(* Reused from existing modules: Helpers.{signed_command,           *)
(* payment_body, delegation_body, set_delegate, get_account_exn},   *)
(* Ledger_helpers.ledger_of_accounts, Test_account.*,               *)
(* Protocol_config_examples.*.                                      *)
(* ---------------------------------------------------------------- *)

let lookup ledger id =
  Option.bind (Ledger.location_of_account ledger id) ~f:(Ledger.get ledger)

(** Apply [txn] to [ledger], returning the applied transaction and a lookup
    function for the pre-apply state captured as a sparse snapshot. *)
let apply_and_snapshot
    ?(global_slot = Mina_numbers.Global_slot_since_genesis.of_int 120)
    ?(txn_state_view = protocol_state) ledger txn =
  let account_ids = Transaction.accounts_referenced txn in
  let pre = Sparse_ledger.of_ledger_subset_exn ledger account_ids in
  let applied =
    Transaction_logic.apply_transactions ~signature_kind ~constraint_constants
      ~global_slot ~txn_state_view ledger [ txn ]
    |> Or_error.ok_exn |> List.hd_exn
  in
  let get_pre id =
    Option.try_with (fun () ->
        Sparse_ledger.get_exn pre (Sparse_ledger.find_index_exn pre id) )
  in
  (applied, get_pre)

let measure_stake_change ?global_slot ?txn_state_view ledger txn =
  let applied, get_account_pre =
    apply_and_snapshot ?global_slot ?txn_state_view ledger txn
  in
  Transaction_applied.stake_change ~get_account_pre
    ~get_account_post:(lookup ledger) applied
  |> Or_error.ok_exn

let check ~name ~expected actual =
  if not (Amount.Signed.equal actual expected) then
    Alcotest.failf "%s: expected %s, got %s" name
      (Sexp.to_string (Amount.Signed.sexp_of_t expected))
      (Sexp.to_string (Amount.Signed.sexp_of_t actual))

let plus = Amount.Signed.of_unsigned

let neg u = Amount.Signed.negate (plus u)

let fee_amt = Amount.of_fee

let balance_amt = Balance.to_amount

let add_signed a b = Option.value_exn (Amount.Signed.add a b)

let gen_account ?(min_balance = 5) ?(max_balance = 1_000_000) () =
  Test_account.gen_constrained_balance
    ~min:(Balance.of_mina_int_exn min_balance)
    ~max:(Balance.of_mina_int_exn max_balance)
    ()

let gen_pair_and_fee =
  let open Quickcheck.Generator.Let_syntax in
  let%bind sender = gen_account () in
  let%bind receiver = gen_account ~min_balance:0 () in
  let%map fee = Fee.gen_incl Fee.one (Fee.of_mina_int_exn 1) in
  (sender, receiver, fee)

let ledger_of accounts =
  Ledger_helpers.ledger_of_accounts
    ~depth:(Fixed_depth constraint_constants.ledger_depth) accounts
  |> Or_error.ok_exn

let trials = 20

(* ---------------------------------------------------------------- *)
(* Payment                                                          *)
(* ---------------------------------------------------------------- *)

let payment_success_neither_staked () =
  Quickcheck.test ~trials gen_pair_and_fee ~f:(fun (sender, receiver, fee) ->
      let amount = Amount.of_mina_int_exn 1 in
      let ledger = ledger_of [ sender; receiver ] in
      let txn = signed_command ~sender ~fee (payment_body ~receiver ~amount) in
      check ~name:"payment success neither staked" ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

let payment_success_both_staked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 gen_pair_and_fee Public_key.Compressed.gen)
    ~f:(fun ((sender, receiver, fee), validator) ->
      let amount = Amount.of_mina_int_exn 1 in
      let ledger = ledger_of [ sender; receiver ] in
      set_delegate ledger sender.pk (Some validator) ;
      set_delegate ledger receiver.pk (Some validator) ;
      let txn = signed_command ~sender ~fee (payment_body ~receiver ~amount) in
      check ~name:"payment success both staked"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

let payment_success_sender_staked_only () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 gen_pair_and_fee Public_key.Compressed.gen)
    ~f:(fun ((sender, receiver, fee), validator) ->
      let amount = Amount.of_mina_int_exn 1 in
      let ledger = ledger_of [ sender; receiver ] in
      set_delegate ledger sender.pk (Some validator) ;
      let txn = signed_command ~sender ~fee (payment_body ~receiver ~amount) in
      (* fp=1, recv=0  →  −fee·1 + amount·(0−1) = −(fee + amount) *)
      let expected = add_signed (neg (fee_amt fee)) (neg amount) in
      check ~name:"payment success sender staked only" ~expected
        (measure_stake_change ledger txn) )

let payment_success_receiver_staked_only () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 gen_pair_and_fee Public_key.Compressed.gen)
    ~f:(fun ((sender, receiver, fee), validator) ->
      let amount = Amount.of_mina_int_exn 1 in
      let ledger = ledger_of [ sender; receiver ] in
      set_delegate ledger receiver.pk (Some validator) ;
      let txn = signed_command ~sender ~fee (payment_body ~receiver ~amount) in
      (* fp=0, recv=1  →  0 + amount·(1−0) = +amount *)
      check ~name:"payment success receiver staked only" ~expected:(plus amount)
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Stake_delegation                                                 *)
(* ---------------------------------------------------------------- *)

(* For a stake_delegation to succeed, the new-delegate account must exist
   in the ledger (the receiver_pk is looked up and must not be an empty
   slot). Tests that want success place a [validator] account in the
   ledger and target it. *)

let delegation_some_to_some () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 gen_pair_and_fee Public_key.Compressed.gen)
    ~f:(fun ((sender, validator, fee), old_delegate) ->
      let ledger = ledger_of [ sender; validator ] in
      set_delegate ledger sender.pk (Some old_delegate) ;
      let txn =
        signed_command ~sender ~fee (delegation_body ~new_delegate:validator.pk)
      in
      check ~name:"delegation some→some"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

let delegation_some_to_none () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 gen_pair_and_fee Public_key.Compressed.gen)
    ~f:(fun ((sender, _, fee), old_delegate) ->
      let ledger = ledger_of [ sender ] in
      set_delegate ledger sender.pk (Some old_delegate) ;
      let txn =
        signed_command ~sender ~fee
          (delegation_body ~new_delegate:Public_key.Compressed.empty)
      in
      check ~name:"delegation some→none (opt-out)"
        ~expected:(neg (balance_amt sender.balance))
        (measure_stake_change ledger txn) )

let delegation_none_to_some () =
  Quickcheck.test ~trials gen_pair_and_fee ~f:(fun (sender, validator, fee) ->
      let ledger = ledger_of [ sender; validator ] in
      let txn =
        signed_command ~sender ~fee (delegation_body ~new_delegate:validator.pk)
      in
      let expected =
        add_signed (plus (balance_amt sender.balance)) (neg (fee_amt fee))
      in
      check ~name:"delegation none→some (opt-in)" ~expected
        (measure_stake_change ledger txn) )

let delegation_none_to_none () =
  Quickcheck.test ~trials gen_pair_and_fee ~f:(fun (sender, _, fee) ->
      let ledger = ledger_of [ sender ] in
      let txn =
        signed_command ~sender ~fee
          (delegation_body ~new_delegate:Public_key.Compressed.empty)
      in
      check ~name:"delegation none→none" ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

(* Failed: delegating to an unknown receiver pk. Expected: −fee·fp. *)
let delegation_failed_sender_staked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3 gen_pair_and_fee Public_key.Compressed.gen
        Public_key.Compressed.gen)
    ~f:(fun ((sender, _, fee), old_delegate, unknown_pk) ->
      let ledger = ledger_of [ sender ] in
      set_delegate ledger sender.pk (Some old_delegate) ;
      let txn =
        signed_command ~sender ~fee (delegation_body ~new_delegate:unknown_pk)
      in
      check ~name:"delegation failed (unknown receiver), sender staked"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

let delegation_failed_sender_unstaked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 gen_pair_and_fee Public_key.Compressed.gen)
    ~f:(fun ((sender, _, fee), unknown_pk) ->
      let ledger = ledger_of [ sender ] in
      let txn =
        signed_command ~sender ~fee (delegation_body ~new_delegate:unknown_pk)
      in
      check ~name:"delegation failed (unknown receiver), sender unstaked"
        ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

(* Not permitted: sender's set_delegate permission rejects signature auth.
   Status is [Failed Update_not_permitted_delegate], fee is still deducted. *)
let delegation_not_permitted_sender_staked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 gen_pair_and_fee Public_key.Compressed.gen)
    ~f:(fun ((sender, validator, fee), old_delegate) ->
      let ledger = ledger_of [ sender; validator ] in
      set_delegate ledger sender.pk (Some old_delegate) ;
      set_permissions ledger sender.pk
        { Permissions.user_default with
          set_delegate = Permissions.Auth_required.Proof
        } ;
      let txn =
        signed_command ~sender ~fee (delegation_body ~new_delegate:validator.pk)
      in
      check ~name:"delegation not permitted, sender staked"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )

let delegation_not_permitted_sender_unstaked () =
  Quickcheck.test ~trials gen_pair_and_fee ~f:(fun (sender, validator, fee) ->
      let ledger = ledger_of [ sender; validator ] in
      set_permissions ledger sender.pk
        { Permissions.user_default with
          set_delegate = Permissions.Auth_required.Proof
        } ;
      let txn =
        signed_command ~sender ~fee (delegation_body ~new_delegate:validator.pk)
      in
      check ~name:"delegation not permitted, sender unstaked"
        ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* TODO: deferred coverage-table row                                *)
(*                                                                  *)
(* Payment, fail. The coverage-table row is "Payment, fail:         *)
   (* −fee·fp". A failed payment applies (fee deducted, nonce *)
(* incremented) but the body amount does not transfer.              *)
(* Triggering this without having the top-level                     *)
(* Transaction_logic.apply_transactions return Or_error.Error is    *)
(* subtle: sub_amount underflow on the fee-deduction path           *)
(* surfaces as an Or_error.Error, not a Failed user_command.        *)
(* Needs a failure mode that reliably leaves the fee deducted       *)
(* and reports a Failed status (e.g. a source-insufficient-body     *)
(* case guaranteed to pay the fee first).                           *)
(* ---------------------------------------------------------------- *)

(* ---------------------------------------------------------------- *)
(* Fee_transfer                                                     *)
(* ---------------------------------------------------------------- *)

let fee_transfer_one ~recipient ~fee : Mina_transaction.Transaction.t =
  let ft =
    Or_error.ok_exn
      (Fee_transfer.of_singles
         (`One
           (Fee_transfer.Single.create ~receiver_pk:recipient.Test_account.pk
              ~fee ~fee_token:Token_id.default ) ) )
  in
  Mina_transaction.Transaction.Fee_transfer ft

let fee_transfer_two ~recipient1 ~fee1 ~recipient2 ~fee2 :
    Mina_transaction.Transaction.t =
  let single r f =
    Fee_transfer.Single.create ~receiver_pk:r.Test_account.pk ~fee:f
      ~fee_token:Token_id.default
  in
  let ft =
    Or_error.ok_exn
      (Fee_transfer.of_singles
         (`Two (single recipient1 fee1, single recipient2 fee2)) )
  in
  Mina_transaction.Transaction.Fee_transfer ft

(* Fee_transfer, one single. Recipient in ledger (avoids account creation
   fee deduction). Expected: fee·rcv_staked. *)
let fee_transfer_one_staked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 (gen_account ()) Public_key.Compressed.gen)
    ~f:(fun (recipient, validator) ->
      let fee = Fee.of_mina_int_exn 1 in
      let ledger = ledger_of [ recipient ] in
      set_delegate ledger recipient.pk (Some validator) ;
      let txn = fee_transfer_one ~recipient ~fee in
      check ~name:"fee_transfer one single (staked)"
        ~expected:(plus (fee_amt fee))
        (measure_stake_change ledger txn) )

let fee_transfer_one_unstaked () =
  Quickcheck.test ~trials (gen_account ()) ~f:(fun recipient ->
      let fee = Fee.of_mina_int_exn 1 in
      let ledger = ledger_of [ recipient ] in
      let txn = fee_transfer_one ~recipient ~fee in
      check ~name:"fee_transfer one single (unstaked)"
        ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

(* Fee_transfer, two singles. Expected: fee₂·pk₂_staked + fee₁·pk₁_staked. *)
let fee_transfer_two_mixed () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 (gen_account ()) (gen_account ()))
    ~f:(fun (recipient1, recipient2) ->
      let fee1 = Fee.of_mina_int_exn 1 in
      let fee2 = Fee.of_mina_int_exn 2 in
      let validator = Quickcheck.random_value Public_key.Compressed.gen in
      let ledger = ledger_of [ recipient1; recipient2 ] in
      (* Stake recipient1 only. *)
      set_delegate ledger recipient1.pk (Some validator) ;
      let txn = fee_transfer_two ~recipient1 ~fee1 ~recipient2 ~fee2 in
      check ~name:"fee_transfer two singles (only pk1 staked)"
        ~expected:(plus (fee_amt fee1))
        (measure_stake_change ledger txn) )

(* ---------------------------------------------------------------- *)
(* Coinbase                                                         *)
(* ---------------------------------------------------------------- *)

let coinbase ~receiver ~amount ~fee_transfer : Mina_transaction.Transaction.t =
  let cb =
    Or_error.ok_exn
      (Coinbase.create ~amount ~receiver:receiver.Test_account.pk ~fee_transfer)
  in
  Mina_transaction.Transaction.Coinbase cb

(* Coinbase, no fee_transfer. Expected: full · rcv_staked. *)
let coinbase_no_ft_staked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 (gen_account ()) Public_key.Compressed.gen)
    ~f:(fun (receiver, validator) ->
      let amount = Amount.of_mina_int_exn 720 in
      let ledger = ledger_of [ receiver ] in
      set_delegate ledger receiver.pk (Some validator) ;
      let txn = coinbase ~receiver ~amount ~fee_transfer:None in
      check ~name:"coinbase no fee_transfer (staked)" ~expected:(plus amount)
        (measure_stake_change ledger txn) )

let coinbase_no_ft_unstaked () =
  Quickcheck.test ~trials (gen_account ()) ~f:(fun receiver ->
      let amount = Amount.of_mina_int_exn 720 in
      let ledger = ledger_of [ receiver ] in
      let txn = coinbase ~receiver ~amount ~fee_transfer:None in
      check ~name:"coinbase no fee_transfer (unstaked)"
        ~expected:Amount.Signed.zero
        (measure_stake_change ledger txn) )

(* Coinbase, with fee_transfer. Expected: ft_fee·ft_staked + (full − ft_fee)·rcv_staked. *)
let coinbase_with_ft_mixed () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(tuple2 (gen_account ()) (gen_account ()))
    ~f:(fun (receiver, ft_recipient) ->
      let full = Amount.of_mina_int_exn 720 in
      let ft_fee = Fee.of_mina_int_exn 10 in
      let validator = Quickcheck.random_value Public_key.Compressed.gen in
      let ledger = ledger_of [ receiver; ft_recipient ] in
      (* Stake coinbase receiver only. *)
      set_delegate ledger receiver.pk (Some validator) ;
      let ft =
        Coinbase_fee_transfer.create ~receiver_pk:ft_recipient.pk ~fee:ft_fee
      in
      let txn = coinbase ~receiver ~amount:full ~fee_transfer:(Some ft) in
      let expected =
        Option.value_exn (Amount.sub full (fee_amt ft_fee)) |> plus
      in
      check ~name:"coinbase with ft (only cb receiver staked)" ~expected
        (measure_stake_change ledger txn) )
