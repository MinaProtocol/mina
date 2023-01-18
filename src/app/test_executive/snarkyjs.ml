open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let initial_fee_payer_balance = Currency.Balance.of_mina_string_exn "8000000"

  let zkapp_target_balance = Currency.Balance.of_mina_string_exn "10"

  let config =
    let open Test_config in
    let open Test_config.Wallet in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = Currency.Balance.to_mina_string initial_fee_payer_balance
          ; timing = Untimed
          }
        ]
    ; extra_genesis_accounts = [ { balance = "10"; timing = Untimed } ]
    ; num_snark_workers = 0
    }
  let check_and_print_stout_stderr ~logger process = 
    let open Deferred.Let_syntax in
    let%map output = Async_unix.Process.collect_output_and_wait process in
    let stdout = String.strip output.stdout in
    [%log info] "Stdout: $stdout" ~metadata:[ ("stdout", `String stdout) ] ;
    if not (String.is_empty output.stderr) then
      Malleable_error.hard_error (Error.of_string output.stderr)
    else Malleable_error.ok_unit

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in

    let block_producer_nodes = Network.block_producers network in
    let node = List.hd_exn block_producer_nodes in
    let%bind my_sk = priv_key_of_node node in
    let ({ private_key = zkapp_sk; public_key = _zkapp_pk }
          : Signature_lib.Keypair.t ) =
      Signature_lib.Keypair.create ()
    in
    let graphql_uri =
      Network.Node.graphql_uri node
    in

    let%bind () =
      [%log info] "Waiting for nodes to be initialized" ;
      let%bind () = wait_for t (Wait_condition.node_to_initialize node) in 
      let%bind.Deferred result =
        Deferred.return
          (let%bind.Deferred process =
             Async_unix.Process.create_exn
               ~prog:"./src/lib/snarky_js_bindings/test_module/node"
               ~args:
                 [ "src/lib/snarky_js_bindings/test_module/simple-zkapp.js"
                 ; Signature_lib.Private_key.to_base58_check zkapp_sk
                 ; Signature_lib.Private_key.to_base58_check my_sk
                 ; graphql_uri
                 ]
               ()
           in
           check_and_print_stout_stderr ~logger process )
      in
      return ()
    in
    return ()
end
