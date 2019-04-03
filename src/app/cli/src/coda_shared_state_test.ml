open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

let name = "coda-shared-state-test"

let main () =
  let logger = Logger.create () in
  let n = 2 in
  let keypairs =
    List.map Genesis_ledger.accounts
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  let snark_work_public_keys i =
    Some ((List.nth_exn keypairs i).public_key |> Public_key.compress)
  in
  let%bind testnet =
    Coda_worker_testnet.test logger n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  let%bind () =
    Coda_worker_testnet.Payments.send_several_payments testnet ~node:0
      ~keypairs ~n:3
  in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share states"
    (Command.Param.return main)
