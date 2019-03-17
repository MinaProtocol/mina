open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

let name = "coda-shared-state-test"

let main () =
  let open Keypair in
  let log = Logger.create () in
  let log = Logger.child log name in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  let another_account_keypair =
    Genesis_ledger.find_new_account_record_exn
      [largest_account_keypair.public_key]
    |> Genesis_ledger.keypair_of_account_record_exn
  in
  let n = 2 in
  let proposers i = if i = 0 then Some i else None in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let%bind testnet =
    Coda_worker_testnet.test log n proposers snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  let receiver_pk = Public_key.compress another_account_keypair.public_key in
  let sender_sk = largest_account_keypair.private_key in
  let%bind () =
    Coda_worker_testnet.Payments.send_several_payments testnet ~node:0
      ~src:sender_sk ~dest:receiver_pk
  in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share states"
    (Command.Param.return main)
