open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

let name = "coda-receipt-chain-test"

let lift = Deferred.map ~f:Option.some

(* TODO: This should completely kill the coda daemon for a worker *)
let restart_node testnet i =
  let%bind () = Coda_worker_testnet.Api.stop testnet i in
  let%bind () = after (Time.Span.of_sec 15.) in
  Coda_worker_testnet.Api.start testnet i

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
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let receiver_pk = Public_key.compress another_account_keypair.public_key in
  let sender_sk = largest_account_keypair.private_key in
  let send_amount = Currency.Amount.of_int 10 in
  let fee = Currency.Fee.of_int 0 in
  let%bind testnet =
    Coda_worker_testnet.test log n should_propose snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  let%map result =
    let open Deferred.Option.Let_syntax in
    (* TODO: we should test sending multiple payments simultaneously. See #1143*)
    let%bind receipt_chain_hash =
      Coda_worker_testnet.Api.send_payment_with_receipt testnet 0 sender_sk
        receiver_pk send_amount fee
    in
    let%bind () = restart_node testnet 0 |> lift in
    let%map proof =
      Coda_worker_testnet.Api.prove_receipt testnet 0 receipt_chain_hash
        receipt_chain_hash
    in
    Receipt.Chain_hash.equal
      (Payment_proof.initial_receipt proof)
      receipt_chain_hash
  in
  assert (Option.value ~default:false result)

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that peers can prove sent payments"
    (Command.Param.return main)
