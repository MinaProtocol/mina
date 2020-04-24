open Core
open Async

let name = "coda-block-production-test"

let main ~runtime_config () =
  let logger = Logger.create () in
  let%bind {Precomputed_values.base_proof; runtime_config; _} =
    Deferred.Or_error.ok_exn
    @@ Precomputed_values.load_values ~logger ~not_found:`Generate_and_store
         ~runtime_config ()
  in
  let n = 1 in
  let snark_work_public_keys _ = None in
  let%bind testnet =
    Coda_worker_testnet.test ~name ~runtime_config ~base_proof logger n
      Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None
  in
  let%bind () = after (Time.Span.of_sec 30.) in
  Coda_worker_testnet.Api.teardown testnet ~logger

(* TODO: Test-specific runtime config. *)
let default_runtime_config = Runtime_config.compile_config

let command =
  Command.async ~summary:"Test that blocks get produced"
    (let open Command.Let_syntax in
    let%map runtime_config =
      Runtime_config.from_flags default_runtime_config
    in
    main ~runtime_config)
