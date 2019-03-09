open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

let name = "coda-restart-node-test"

let main () =
  let open Keypair in
  let logger = Logger.create () in
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
  let send_new = true in
  let receiver_pk =
    Public_key.compress
      ( if send_new then
        let keypair = Keypair.create () in
        keypair.public_key
      else another_account_keypair.public_key )
  in
  let sender_sk = largest_account_keypair.private_key in
  let send_amount = Currency.Amount.of_int 10 in
  let fee = Currency.Fee.of_int 0 in
  let%bind testnet =
    Coda_worker_testnet.test logger n proposers snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  let%bind () = after (Time.Span.of_sec 5.) in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "Stopping %d" 1 ;
  let%bind () = Coda_worker_testnet.Api.stop testnet 1 in
  let%bind () =
    Coda_worker_testnet.Api.send_payment testnet 0 sender_sk receiver_pk
      send_amount fee
  in
  let%bind () = after (Time.Span.of_sec 5.) in
  let%bind () = Coda_worker_testnet.Api.start testnet 1 in
  let%map () = after (Time.Span.of_sec 240.) in
  ()

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test of stopping, waiting, then starting a node"
    (Command.Param.return main)
