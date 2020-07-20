open Core
open Async
open Signature_lib

let name = "coda-batch-payment-test"

let main () =
  Core.Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true ;
  let logger = Logger.create () in
  let precomputed_values = Lazy.force Precomputed_values.compiled in
  let (module Genesis_ledger) = precomputed_values.genesis_ledger in
  let keypairs =
    List.map
      (Lazy.force Genesis_ledger.accounts)
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  let block_production_keys i = if i = 0 then Some i else None in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let num_nodes = 3 in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger num_nodes block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None
      ~runtime_config:
        (Genesis_ledger_helper.extract_runtime_config precomputed_values)
  in
  let%bind payments =
    Coda_worker_testnet.Payments.send_batch_consecutive_payments testnet
      ~node:0 ~keypairs ~sender:largest_account_keypair.private_key ~n:4
  in
  let%bind () =
    Coda_worker_testnet.Payments.assert_retrievable_payments testnet payments
  in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"Test batch payments" (Async.Command.Spec.return main)
