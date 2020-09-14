open Core
open Async
open Coda_base

let name = "coda-receipt-chain-test"

let lift = Deferred.map ~f:Option.some

(* TODO: This should completely kill the coda daemon for a worker *)
let restart_node worker ~config ~logger =
  let%bind () = Coda_process.disconnect worker ~logger in
  Coda_process.spawn_exn config

let main () =
  let precomputed_values =
    (* TODO: Load for this specific test. *)
    Lazy.force Precomputed_values.compiled
  in
  let consensus_constants = precomputed_values.consensus_constants in
  let logger = Logger.create () in
  let sender_sk, largest_account =
    Precomputed_values.largest_account_exn precomputed_values
  in
  let receiver_pk =
    Precomputed_values.find_new_account_record_exn_ precomputed_values
      [Account.public_key largest_account]
    |> Precomputed_values.pk_of_account_record
  in
  let block_production_interval =
    consensus_constants.block_window_duration_ms |> Block_time.Span.to_ms
    |> Int64.to_int_exn
  in
  let acceptable_delay =
    Time.Span.of_ms
      ( block_production_interval
        * Unsigned.UInt32.to_int consensus_constants.delta
      |> Float.of_int )
  in
  let n = 2 in
  let sender_sk = Option.value_exn sender_sk in
  let send_amount = Currency.Amount.of_int 10 in
  let fee = Signed_command.minimum_fee in
  let%bind program_dir = Unix.getcwd () in
  let work_selection_method =
    Cli_lib.Arg_type.Work_selection_method.Sequence
  in
  Parallel.init_master () ;
  let%bind configs =
    Coda_processes.local_configs n ~program_dir ~block_production_interval
      ~acceptable_delay ~chain_id:name ~snark_worker_public_keys:None
      ~block_production_keys:(Fn.const None) ~work_selection_method
      ~trace_dir:(Unix.getenv "CODA_TRACING")
      ~max_concurrent_connections:None
      ~runtime_config:precomputed_values.runtime_config
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let worker = List.hd_exn workers in
  let config = List.hd_exn configs in
  let%bind receipt_chain_hash =
    Coda_process.send_user_command_exn worker sender_sk receiver_pk send_amount
      fee Signed_command_memo.dummy
  in
  let _user_cmd, receipt_chain_hash = Or_error.ok_exn receipt_chain_hash in
  let%bind restarted_worker = restart_node ~config worker ~logger in
  let%bind (initial_receipt, _)
             : Receipt.Chain_hash.t * Command_transaction.t list =
    Coda_process.prove_receipt_exn restarted_worker receipt_chain_hash
      receipt_chain_hash
  in
  let result = Receipt.Chain_hash.equal initial_receipt receipt_chain_hash in
  assert result ;
  Deferred.List.iter workers ~f:(Coda_process.disconnect ~logger)

let command =
  Command.async ~summary:"Test that peers can prove sent payments"
    (Command.Param.return main)
