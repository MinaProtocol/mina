open Core
open Mina_base
open Mina_base_test_helpers
open Mina_numbers
open Signature_lib
module Ledger = Mina_ledger.Ledger.Ledger_inner

let noncemap (accounts : Test_account.t list) :
    Account_nonce.t Public_key.Compressed.Map.t =
  Public_key.Compressed.Map.of_alist_exn
  @@ List.map ~f:(fun a -> (a.pk, a.nonce)) accounts

let bin_log n =
  let rec find candidate =
    if Int.pow 2 candidate >= n then candidate else find (Int.succ candidate)
  in
  find 0

let ledger_of_accounts accounts =
  let open Result.Let_syntax in
  let open Test_account in
  let module R = Monad_lib.Make_ext2 (Result) in
  let depth = bin_log @@ List.length accounts in
  let ledger = Ledger.empty ~depth () in
  let%map () =
    R.iter_m accounts ~f:(fun a ->
        let acc_id = account_id a in
        let account : Account.t = Account.initialize acc_id in
        Ledger.create_new_account ledger acc_id
          { account with
            balance = a.balance
          ; nonce = a.nonce
          ; zkapp = a.zkapp
          ; token_id = a.token_id
          } )
  in
  ledger
