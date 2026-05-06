(** Shared helpers for [stake_change.ml] (non-zkApp coverage table) and
    [zkapp_stake_change.ml] (zkApp case spine).

    These all operate on [Mina_transaction.Transaction.t], so the same
    [apply_and_snapshot] / [measure_stake_change] pipeline drives both
    suites — the zkApp tests just feed a [Command (Zkapp_command _)]. *)

open Core_kernel
open Currency
open Mina_base_test_helpers
open Mina_ledger_test_helpers
open Transaction_logic_tests
open Protocol_config_examples
open Helpers
module Sparse_ledger = Mina_ledger.Sparse_ledger
module Transaction = Mina_transaction.Transaction
module Transaction_applied = Mina_transaction_logic.Transaction_applied

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
  Transaction_applied.stake_change_of_transaction ~get_account_pre
    ~get_account_post:(lookup ledger)
    (Transaction_applied.transaction applied)
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
