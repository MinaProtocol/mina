open Core
open Async
open Signature_lib

let name = "coda-shared-prefix-multiproducer-test"

let main ~runtime_config n enable_payments () =
  let logger = Logger.create () in
  let%bind {Precomputed_values.genesis_ledger; base_proof; runtime_config; _} =
    Deferred.Or_error.ok_exn
    @@ Precomputed_values.load_values ~logger ~not_found:`Generate_and_store
         ~runtime_config ()
  in
  let (module Genesis_ledger : Genesis_ledger.Intf.S) = genesis_ledger in
  let keypairs =
    List.map
      (Lazy.force Genesis_ledger.accounts)
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  let snark_work_public_keys i =
    Some ((List.nth_exn keypairs i).public_key |> Public_key.compress)
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config ~base_proof
  in
  let%bind () =
    if enable_payments then
      Coda_worker_testnet.Payments.send_several_payments testnet ~node:0
        ~keypairs ~n:3
    else after (Time.Span.of_min 3.)
  in
  Coda_worker_testnet.Api.teardown testnet ~logger

(* TODO: Test-specific runtime config. *)
let default_runtime_config = Runtime_config.compile_config

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (let%map_open num_block_producers =
       flag "num-block-producers" ~doc:"NUM number of block producers to have"
         (required int)
     and enable_payments =
       flag "payments" no_arg ~doc:"enable the payment check"
     and runtime_config = Runtime_config.from_flags default_runtime_config in
     main ~runtime_config num_block_producers enable_payments)
