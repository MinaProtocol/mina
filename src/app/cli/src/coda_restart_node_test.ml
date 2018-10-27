open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

module Make (Kernel : Kernel_intf) : Integration_test_intf.S = struct
  module Coda_processes = Coda_processes.Make (Kernel)
  open Coda_processes
  module Coda_worker_testnet = Coda_worker_testnet.Make (Kernel)

  let name = "coda-restart-node-test"

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
    let should_propose i = i = 0 in
    let snark_work_public_keys i =
      if i = 0 then
        Some (Public_key.compress largest_account_keypair.public_key)
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
      Coda_worker_testnet.test log n should_propose snark_work_public_keys
        Protocols.Coda_pow.Work_selection.Seq
    in
    let%bind () = after (Time.Span.of_sec 5.) in
    Logger.info log "Stopping %d" 1 ;
    let%bind () = Coda_worker_testnet.Api.stop testnet 1 in
    let%bind () =
      Coda_worker_testnet.Api.send_transaction testnet 0 sender_sk receiver_pk
        send_amount fee
    in
    let%bind () = after (Time.Span.of_sec 5.) in
    let%bind () = Coda_worker_testnet.Api.start testnet 1 in
    let%map () = after (Time.Span.of_sec 20.) in
    ()

  let command =
    Command.async_spec
      ~summary:"Test of stopping, waiting, then starting a node"
      Command.Spec.(empty)
      main
end
