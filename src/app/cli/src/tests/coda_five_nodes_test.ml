open Core
open Async
open Coda_base

let name = "coda-five-nodes-test"

let main ~runtime_config () =
  let logger = Logger.create () in
  let%bind {Precomputed_values.genesis_ledger; base_proof; runtime_config; _} =
    Deferred.Or_error.ok_exn
    @@ Precomputed_values.load_values ~logger ~not_found:`Generate_and_store
         ~runtime_config ()
  in
  let (module Genesis_ledger : Genesis_ledger.Intf.S) = genesis_ledger in
  let n = 5 in
  let snark_work_public_keys = function
    | 0 ->
        Some
          ( List.nth_exn (Lazy.force Genesis_ledger.accounts) 5
          |> snd |> Account.public_key )
    | _ ->
        None
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config ~base_proof
  in
  let%bind () = after (Time.Span.of_min 10.) in
  Coda_worker_testnet.Api.teardown testnet ~logger

(* TODO: Test-specific runtime config. *)
let default_runtime_config = Runtime_config.compile_config

let command =
  Command.async ~summary:"Test that five nodes work"
    (let open Command.Let_syntax in
    let%map runtime_config =
      Runtime_config.from_flags default_runtime_config
    in
    main ~runtime_config)
