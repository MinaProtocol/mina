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
module Transaction = Mina_transaction.Transaction

let zkapp_txn ~fee_payer ~fee ?(transactions = []) accounts : Transaction.t =
  let cmd =
    Zkapp_cmd_builder.zkapp_cmd
      ~noncemap:(Ledger_helpers.noncemap accounts)
      ~fee:(fee_payer.Test_account.pk, fee)
      transactions
  in
  Command (User_command.Zkapp_command cmd)

(* ---------------------------------------------------------------- *)
(* Baseline: fee_payer-only zkApp txs (empty call forest).          *)
(* ---------------------------------------------------------------- *)

(* zkapp_stake_change_row_z1 *)
let z1_fee_payer_only_staked () =
  Quickcheck.test ~trials
    Quickcheck.Generator.(
      tuple3 (gen_account ()) Public_key.Compressed.gen
        (Fee.gen_incl Fee.one (Fee.of_mina_int_exn 1)))
    ~f:(fun (fp, validator, fee) ->
      let ledger = ledger_of [ fp ] in
      set_delegate ledger fp.pk (Some validator) ;
      let txn = zkapp_txn ~fee_payer:fp ~fee [ fp ] in
      check ~name:"z1 fee_payer staked, no other updates"
        ~expected:(neg (fee_amt fee))
        (measure_stake_change ledger txn) )
