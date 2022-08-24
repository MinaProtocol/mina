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

  let initial_fee_payer_balance = Currency.Balance.of_formatted_string "8000000"

  let zkapp_target_balance = Currency.Balance.of_formatted_string "10"

  let config =
    let open Test_config in
    let open Test_config.Wallet in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance =
              Currency.Balance.to_formatted_string initial_fee_payer_balance
          ; timing = Untimed
          }
        ]
    ; extra_genesis_accounts = [ { balance = "10"; timing = Untimed } ]
    ; num_snark_workers = 0
    }

  let wait_and_stdout ~logger process =
    let open Deferred.Let_syntax in
    let%map output = Async_unix.Process.collect_output_and_wait process in
    let stdout = String.strip output.stdout in
    [%log info] "Stdout: $stdout" ~metadata:[ ("stdout", `String stdout) ] ;
    if not (String.is_empty output.stderr) then
      [%log warn] "Stderr: $stderr"
        ~metadata:[ ("stderr", `String output.stderr) ] ;
    String.split stdout ~on:'\n' |> List.last_exn

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let wait_for_zkapp parties =
      let with_timeout =
        let soft_timeout = Network_time_span.Slots 3 in
        let hard_timeout = Network_time_span.Slots 4 in
        Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
      in
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures:false
             ~parties
      in
      [%log info] "zkApp transaction included in transition frontier"
    in
    let block_producer_nodes = Network.block_producers network in
    let node = List.hd_exn block_producer_nodes in
    let%bind my_pk = Util.pub_key_of_node node in
    let%bind my_sk = Util.priv_key_of_node node in
    let my_account_id =
      Mina_base.Account_id.create my_pk Mina_base.Token_id.default
    in
    let ({ private_key = zkapp_sk; public_key = zkapp_pk }
          : Signature_lib.Keypair.t ) =
      Signature_lib.Keypair.create ()
    in
    let zkapp_pk = Signature_lib.Public_key.compress zkapp_pk in
    let zkapp_account_id =
      Mina_base.Account_id.create zkapp_pk Mina_base.Token_id.default
    in
    let make_sign_and_send which =
      let which_str, nonce =
        match which with
        | `Deploy ->
            ("deploy", "0")
        | `Update ->
            ("update", "1")
      in
      (* concurrently make/sign the deploy transaction and wait for the node to be ready *)
      [%log info] "Running JS script with command $jscommand"
        ~metadata:[ ("jscommand", `String which_str) ] ;
      let%bind.Deferred parties_contract_str, unit_with_error =
        Deferred.both
          (let%bind.Deferred process =
             Async_unix.Process.create_exn
               ~prog:"./src/lib/snarky_js_bindings/test_module/node"
               ~args:
                 [ "src/lib/snarky_js_bindings/test_module/simple-zkapp.js"
                 ; which_str
                 ; Signature_lib.Private_key.to_base58_check zkapp_sk
                 ; Signature_lib.Private_key.to_base58_check my_sk
                 ; nonce
                 ]
               ()
           in
           wait_and_stdout ~logger process )
          (wait_for t (Wait_condition.node_to_initialize node))
      in
      let parties_contract =
        Mina_base.Parties.of_json (Yojson.Safe.from_string parties_contract_str)
      in
      let%bind () = Deferred.return unit_with_error in
      (* TODO: switch to external sending script once the rest is working *)
      let%bind () = send_zkapp ~logger node parties_contract in
      return parties_contract
    in
    let%bind parties_deploy_contract = make_sign_and_send `Deploy in
    let%bind () =
      section
        "Wait for deploy contract transaction to be included in transition \
         frontier"
        (wait_for_zkapp parties_deploy_contract)
    in
    let%bind parties_update_contract = make_sign_and_send `Update in
    let%bind () =
      section
        "Wait for update contract transaction to be included in transition \
         frontier"
        (wait_for_zkapp parties_update_contract)
    in
    let%bind () =
      section "Verify that the update transaction did update the ledger"
        ( [%log info] "Verifying account state change"
            ~metadata:
              [ ("account_id", Mina_base.Account_id.to_yojson my_account_id) ] ;
          let%bind { total_balance = zkapp_balance; _ } =
            Network.Node.must_get_account_data ~logger node
              ~account_id:zkapp_account_id
          in
          let%bind zkapp_account_update =
            Network.Node.get_account_update ~logger node
              ~account_id:zkapp_account_id
            |> Deferred.bind ~f:Malleable_error.or_hard_error
          in
          let%bind () =
            let zkapp_first_state =
              Mina_base.Zkapp_state.V.to_list zkapp_account_update.app_state
              |> List.hd_exn
            in
            let module Set_or_keep = Mina_base.Zkapp_basic.Set_or_keep in
            let module Field = Snark_params.Tick0.Field in
            let expected = Set_or_keep.Set (Field.of_int 3) in
            if Set_or_keep.equal Field.equal zkapp_first_state expected then (
              [%log info] "Ledger sees state update in zkapp execution" ;
              return () )
            else
              let to_yojson =
                Set_or_keep.to_yojson (fun x -> `String (Field.to_string x))
              in
              [%log error]
                "Ledger does not see state update $expected from zkapp \
                 execution ( actual $actual )"
                ~metadata:
                  [ ("expected", to_yojson expected)
                  ; ("actual", to_yojson zkapp_first_state)
                  ] ;
              Malleable_error.hard_error
                (Error.of_string
                   "State update not witnessed from smart contract execution" )
          in
          if Currency.Balance.(equal zkapp_balance zkapp_target_balance) then (
            [%log info] "Ledger sees balance change from zkapp execution" ;
            return () )
          else (
            [%log error]
              "Ledger does not see zkapp balance $balance = $target (10 MINA)"
              ~metadata:
                [ ("balance", Currency.Balance.to_yojson zkapp_balance)
                ; ("target", Currency.Balance.to_yojson zkapp_target_balance)
                ] ;
            Malleable_error.hard_error
              (Error.of_string
                 "Balance changes not witnessed from smart contract execution" )
            ) )
    in
    return ()
end
