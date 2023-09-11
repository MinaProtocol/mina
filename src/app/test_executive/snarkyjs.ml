open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  let test_name = "snarkyjs"

  let config =
    let open Test_config in
    let open Node_config in
    { default with
      genesis_ledger =
        [ test_account "node-key" "8000000"; test_account "extra-key" "10" ]
    ; block_producers = [ bp "node" () ]
    }

  let check_and_print_stout_stderr ~logger process =
    let open Deferred.Let_syntax in
    let%map output = Async_unix.Process.collect_output_and_wait process in
    let stdout = String.strip output.stdout in
    [%log info] "Stdout: $stdout" ~metadata:[ ("stdout", `String stdout) ] ;
    if not (String.is_empty output.stderr) then (
      [%log error]
        "An error occured during the execution of the test script: \"%s\""
        output.stderr ;
      Malleable_error.hard_error_string output.stderr )
    else Malleable_error.ok_unit

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let node =
      Core.String.Map.find_exn (Network.block_producers network) "node"
    in
    let%bind fee_payer_key = priv_key_of_node node in
    let graphql_uri = Network.Node.get_ingress_uri node |> Uri.to_string in

    let%bind () =
      [%log info] "Waiting for nodes to be initialized" ;
      let%bind () = wait_for t (Wait_condition.node_to_initialize node) in
      [%log info] "Running test script" ;
      let%bind.Deferred result =
        let%bind.Deferred process =
          Async_unix.Process.create_exn
            ~prog:"./src/lib/snarkyjs/tests/integration/node"
            ~args:
              [ "src/lib/snarkyjs/tests/integration/simple-zkapp.js"
              ; Signature_lib.Private_key.to_base58_check fee_payer_key
              ; graphql_uri
              ]
            ()
        in
        check_and_print_stout_stderr ~logger process
      in
      section "Waiting for script to run and complete" result
    in
    return ()
end
