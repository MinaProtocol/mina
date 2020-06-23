open Core
open Async

let name = "coda-shared-prefix-multiproducer-test"

let runtime_config =
  lazy
    ( (* TODO: Decide on a profile for this test.
         (This uses multiple profiles on CI)
      *)
      "{}" |> Yojson.Safe.from_string |> Runtime_config.of_yojson
    |> Result.ok_or_failwith )

let main n enable_payments () =
  let logger = Logger.create () in
  let%bind precomputed_values, runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let keypairs =
    List.map
      (Lazy.force (Precomputed_values.accounts precomputed_values))
      ~f:Precomputed_values.keypair_of_account_record_exn
  in
  let public_keys =
    List.map ~f:Precomputed_values.pk_of_account_record
      (Lazy.force (Precomputed_values.accounts precomputed_values))
  in
  let snark_work_public_keys i = Some (List.nth_exn public_keys i) in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config
  in
  let%bind () =
    if enable_payments then
      Coda_worker_testnet.Payments.send_several_payments testnet ~node:0
        ~keypairs ~n:3
    else after (Time.Span.of_min 3.)
  in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (let%map_open num_block_producers =
       flag "num-block-producers" ~doc:"NUM number of block producers to have"
         (required int)
     and enable_payments =
       flag "payments" no_arg ~doc:"enable the payment check"
     in
     main num_block_producers enable_payments)
