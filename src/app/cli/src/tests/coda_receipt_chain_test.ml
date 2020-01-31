open Core
open Async
open Coda_base
open Signature_lib

let name = "coda-receipt-chain-test"

let lift = Deferred.map ~f:Option.some

(* TODO: This should completely kill the coda daemon for a worker *)
let restart_node worker ~config ~logger =
  let%bind () = Coda_process.disconnect worker ~logger in
  Coda_process.spawn_exn config

let main () =
  let open Keypair in
  let logger = Logger.create () in
  let largest_account_keypair =
    Test_genesis_ledger.largest_account_keypair_exn ()
  in
  let another_account_keypair =
    Test_genesis_ledger.find_new_account_record_exn
      [largest_account_keypair.public_key]
    |> Test_genesis_ledger.keypair_of_account_record_exn
  in
  let block_production_interval =
    Consensus.Constants.block_window_duration_ms
  in
  let acceptable_delay =
    Time.Span.of_ms
      (block_production_interval * Consensus.Constants.delta |> Float.of_int)
  in
  let n = 2 in
  let receiver_pk = Public_key.compress another_account_keypair.public_key in
  let sender_sk = largest_account_keypair.private_key in
  let send_amount = Currency.Amount.of_int 10 in
  let fee = User_command.minimum_fee in
  let%bind program_dir = Unix.getcwd () in
  let work_selection_method =
    Cli_lib.Arg_type.Work_selection_method.Sequence
  in
  Parallel.init_master () ;
  let configs =
    Coda_processes.local_configs n ~program_dir ~block_production_interval
      ~acceptable_delay ~snark_worker_public_keys:None
      ~block_production_keys:(Fn.const None) ~work_selection_method
      ~trace_dir:(Unix.getenv "CODA_TRACING")
      ~max_concurrent_connections:None
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let worker = List.hd_exn workers in
  let config = List.hd_exn configs in
  let%bind receipt_chain_hash =
    Coda_process.send_user_command_exn worker sender_sk receiver_pk send_amount
      fee User_command_memo.dummy
  in
  let receipt_chain_hash = Or_error.ok_exn receipt_chain_hash in
  let%bind restarted_worker = restart_node ~config worker ~logger in
  let%bind (initial_receipt, _) : Receipt.Chain_hash.t * User_command.t list =
    Coda_process.prove_receipt_exn restarted_worker receipt_chain_hash
      receipt_chain_hash
  in
  let result = Receipt.Chain_hash.equal initial_receipt receipt_chain_hash in
  assert result ;
  Deferred.List.iter workers ~f:(Coda_process.disconnect ~logger)

let command =
  Command.async ~summary:"Test that peers can prove sent payments"
    (Command.Param.return main)
