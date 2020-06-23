open Core
open Async
open Coda_base

let name = "coda-five-nodes-test"

let runtime_config =
  lazy
    ( (* TODO: Decide on a profile for this test.
         (It has never been used on CI.)
      *)
      "{}" |> Yojson.Safe.from_string |> Runtime_config.of_yojson
    |> Result.ok_or_failwith )

let main () =
  let logger = Logger.create () in
  let%bind precomputed_values, runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let n = 5 in
  let snark_work_public_keys = function
    | 0 ->
        Some
          ( Precomputed_values.accounts precomputed_values
          |> Lazy.force |> Fn.flip List.nth_exn 5 |> snd |> Account.public_key
          )
    | _ ->
        None
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config
  in
  let%bind () = after (Time.Span.of_min 10.) in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"Test that five nodes work"
    (Command.Param.return main)
