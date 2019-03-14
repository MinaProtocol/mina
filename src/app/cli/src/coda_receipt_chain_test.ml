open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

let name = "coda-receipt-chain-test"

let lift = Deferred.map ~f:Option.some

(* TODO: This should completely kill the coda daemon for a worker *)
let restart_node worker ~config =
  let%bind () = Coda_process.disconnect worker in
  Coda_process.spawn_exn config

let main () =
  let open Keypair in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  let another_account_keypair =
    Genesis_ledger.find_new_account_record_exn
      [largest_account_keypair.public_key]
    |> Genesis_ledger.keypair_of_account_record_exn
  in
  let proposal_interval = Consensus.Constants.block_window_duration_ms in
  let acceptable_delay =
    Time.Span.of_ms
      (proposal_interval * Consensus.Constants.delta |> Float.of_int)
  in
  let n = 2 in
  let receiver_pk = Public_key.compress another_account_keypair.public_key in
  let sender_sk = largest_account_keypair.private_key in
  let send_amount = Currency.Amount.of_int 10 in
  let fee = Currency.Fee.of_int 0 in
  let%bind program_dir = Unix.getcwd () in
  let work_selection = Protocols.Coda_pow.Work_selection.Seq in
  Parallel.init_master () ;
  let configs =
    Coda_processes.local_configs n ~program_dir ~proposal_interval
      ~acceptable_delay ~snark_worker_public_keys:None
      ~proposers:(Fn.const None) ~work_selection
      ~trace_dir:(Unix.getenv "CODA_TRACING")
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let worker = List.hd_exn workers in
  let config = List.hd_exn configs in
  let%bind receipt_chain_hash =
    Coda_process.send_payment_exn worker sender_sk receiver_pk send_amount fee
      User_command_memo.dummy
  in
  let receipt_chain_hash = Or_error.ok_exn receipt_chain_hash in
  let%bind restarted_worker = restart_node ~config worker in
  let%map proof =
    Coda_process.prove_receipt_exn restarted_worker receipt_chain_hash
      receipt_chain_hash
  in
  let result =
    Receipt.Chain_hash.equal
      (Payment_proof.initial_receipt proof)
      receipt_chain_hash
  in
  assert result

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that peers can prove sent payments"
    (Command.Param.return main)
