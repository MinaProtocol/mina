open Core
open Async
open Signature_lib

let name = "coda-shared-prefix-multiproposer-test"

let main n enable_payments () =
  let logger = Logger.create () in
  let keypairs =
    List.map Test_genesis_ledger.accounts
      ~f:Test_genesis_ledger.keypair_of_account_record_exn
  in
  let snark_work_public_keys i =
    Some ((List.nth_exn keypairs i).public_key |> Public_key.compress)
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None
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
    (let%map_open num_proposers =
       flag "num-proposers" ~doc:"NUM number of proposers to have"
         (required int)
     and enable_payments =
       flag "payments" no_arg ~doc:"enable the payment check"
     in
     main num_proposers enable_payments)
