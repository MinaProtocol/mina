open Core
open Async

let name = "coda-shared-prefix-test"

let main ~runtime_config who_produces () =
  let logger = Logger.create () in
  let%bind {Precomputed_values.base_proof; runtime_config; _} =
    Deferred.Or_error.ok_exn
    @@ Precomputed_values.load_values ~logger ~not_found:`Generate_and_store
         ~runtime_config ()
  in
  let n = 2 in
  let block_producers i = if i = who_produces then Some i else None in
  let snark_work_public_keys _ = None in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_producers
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config ~base_proof
  in
  let%bind () = after (Time.Span.of_sec 60.) in
  Coda_worker_testnet.Api.teardown testnet ~logger

(* TODO: Test-specific runtime config. *)
let default_runtime_config = Runtime_config.compile_config

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (let%map_open who_produces =
       flag "who-produces" ~doc:"ID node number which will be producing blocks"
         (required int)
     and runtime_config = Runtime_config.from_flags default_runtime_config in
     main ~runtime_config who_produces)
