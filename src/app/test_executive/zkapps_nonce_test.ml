open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  let test_name = "zkapps-nonce"

  let config =
    let open Test_config in
    let open Node_config in
    { default with
      genesis_ledger =
        [ test_account "node-a-key" "8000000000"
        ; test_account "node-b-key" "1000000"
        ; test_account "fish1" "3000"
        ; test_account "fish2" "3000"
        ; test_account "snark-node-key" "0"
        ]
    ; block_producers = [ bp "node-a" (); bp "node-b" () ]
    ; snark_coordinator = snark "snark-node" 5
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.medium
        }
    }

  let transactions_sent = ref 0

  let num_proofs = 2

  let padding_payments () =
    let needed_for_padding =
      Test_config.transactions_needed_for_ledger_proofs config ~num_proofs
    in
    if !transactions_sent >= needed_for_padding then 0
    else needed_for_padding - !transactions_sent

  let send_zkapp ~logger node zkapp_command =
    incr transactions_sent ;
    send_zkapp ~logger node zkapp_command

  (* Call [f] [n] times in sequence *)
  let repeat_seq ~n ~f =
    let open Malleable_error.Let_syntax in
    let rec go n =
      if n = 0 then return ()
      else
        let%bind () = f () in
        go (n - 1)
    in
    go n

  let send_padding_transactions ~fee ~logger ~n nodes =
    let sender = List.nth_exn nodes 0 in
    let receiver = List.nth_exn nodes 1 in
    let open Malleable_error.Let_syntax in
    let%bind sender_pub_key = pub_key_of_node sender in
    let%bind receiver_pub_key = pub_key_of_node receiver in
    repeat_seq ~n ~f:(fun () ->
        Network.Node.must_send_payment ~logger sender ~sender_pub_key
          ~receiver_pub_key ~amount:Currency.Amount.one ~fee
        >>| ignore )

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes =
      Network.block_producers network |> Core.String.Map.data
    in
    let node =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let fish1_kp =
      (Core.String.Map.find_exn (Network.genesis_keypairs network) "fish1")
        .keypair
    in
    let fish1_pk = Signature_lib.Public_key.compress fish1_kp.public_key in
    let fish1_account_id =
      Mina_base.Account_id.create fish1_pk Mina_base.Token_id.default
    in
    let with_timeout ~soft_slots =
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let wait_for_zkapp ~has_failures zkapp_command =
      let%map () =
        wait_for t @@ with_timeout ~soft_slots:4
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures
             ~zkapp_command
      in
      [%log info] "zkApp transaction included in transition frontier"
    in
    (*Wait for first BP to start sending payments and avoid partially filling blocks*)
    let first_bp = List.hd_exn block_producer_nodes in
    let%bind () =
      wait_for t (Wait_condition.nodes_to_initialize [ first_bp ])
    in
    (*Start sending padding transactions to get snarked ledger sooner*)
    let%bind () =
      let fee = Currency.Fee.of_nanomina_int_exn 3_000_000 in
      send_padding_transactions block_producer_nodes ~fee ~logger
        ~n:(padding_payments ())
    in
    (*wait for the rest*)
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (List.filter
              ~f:(fun n ->
                String.(Network.Node.id n <> Network.Node.id first_bp) )
              (Core.String.Map.data (Network.all_nodes network)) ) )
    in
    let keymap =
      List.fold [ fish1_kp ] ~init:Signature_lib.Public_key.Compressed.Map.empty
        ~f:(fun map { private_key; public_key } ->
          Signature_lib.Public_key.Compressed.Map.add_exn map
            ~key:(Signature_lib.Public_key.compress public_key)
            ~data:private_key )
    in
    (*Transaction that updates fee payer account in account_updates.
      The account update should fail due to failing nonce condition if the next transaction with the same fee payer is added to the same block
    *)
    let%bind.Deferred invalid_nonce_zkapp_cmd_from_fish1 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No fish1_kp Token_id.default 0
                   ~preconditions:
                     { Account_update.Preconditions.network =
                         Zkapp_precondition.Protocol_state.accept
                     ; account = Nonce (Account.Nonce.of_int 1)
                     ; valid_while = Ignore
                     } )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"invalid zkapp from fish1" ~fee:12_000_000
             ~fee_payer_pk:fish1_pk ~fee_payer_nonce:(Account.Nonce.of_int 0)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    (*Transaction that updates fee payer account in account_updates but passes
       because the nonce precondition is true. There should be no other fee
       payer updates in the same block*)
    let%bind.Deferred valid_zkapp_cmd_from_fish1 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No fish1_kp Token_id.default 0
                   ~preconditions:
                     { Account_update.Preconditions.network =
                         Zkapp_precondition.Protocol_state.accept
                     ; account = Nonce (Account.Nonce.of_int 2)
                     ; valid_while = Ignore
                     } )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"valid zkapp from fish1" ~fee:12_000_000
             ~fee_payer_pk:fish1_pk ~fee_payer_nonce:(Account.Nonce.of_int 1)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    (*Set fee payer send permission to Proof. New transactions with the same
      fee payer are accepted into the pool.
      Only the ones that make it to the same block are applied.
      The remaining ones in the pool should be evicted because the fee payer will
      no longer have the permission to send with Signature authorization*)
    let%bind.Deferred set_permission_zkapp_cmd_from_fish1 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No fish1_kp Token_id.default 0
                   ~update:
                     { Account_update.Update.dummy with
                       permissions =
                         Set { Permissions.user_default with send = Proof }
                     } )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"precondition zkapp from fish1"
             ~fee:12_000_000 ~fee_payer_pk:fish1_pk
             ~fee_payer_nonce:(Account.Nonce.of_int 2)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    (*Transaction with fee payer update in account_updates. The account update
      should fail if the send permission is changed to Proof*)
    let%bind.Deferred valid_fee_invalid_permission_zkapp_cmd_from_fish1 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No fish1_kp Token_id.default 1
                   ~increment_nonce:true )
                []
            ; mk_node
                (mk_account_update_body Signature No fish1_kp Token_id.default
                   (-1) )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"valid zkapp from fish1" ~fee:12_000_000
             ~fee_payer_pk:fish1_pk ~fee_payer_nonce:(Account.Nonce.of_int 3)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    (*Transaction that doesn't make it into a block and should be evicted from
      the pool after fee payer's send permission is changed
      Making it a low fee transaction to prevent from getting into a block, to
      test transaction pruning*)
    let%bind.Deferred invalid_fee_invalid_permission_zkapp_cmd_from_fish1 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No fish1_kp Token_id.default 0)
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"valid zkapp from fish1" ~fee:2_000_000
             ~fee_payer_pk:fish1_pk ~fee_payer_nonce:(Account.Nonce.of_int 4)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    let snark_work_event_subscription =
      Event_router.on (event_router t) Snark_work_gossip ~f:(fun _ _ ->
          [%log info] "Received new snark work" ;
          Deferred.return `Continue )
    in
    let snark_work_failure_subscription =
      Event_router.on (event_router t) Snark_work_failed ~f:(fun _ _ ->
          [%log error]
            "A snark worker encountered an error while creating a proof" ;
          Deferred.return `Continue )
    in
    let%bind () =
      section_hard
        "Send a zkapp commands with fee payer nonce increments and nonce \
         preconditions"
        (send_zkapp_batch ~logger node
           [ invalid_nonce_zkapp_cmd_from_fish1; valid_zkapp_cmd_from_fish1 ] )
    in
    let%bind () =
      section_hard
        "Wait for fish1 zkapp command with failing nonce check to appear in \
         transition frontier with failed status"
        (wait_for_zkapp ~has_failures:true invalid_nonce_zkapp_cmd_from_fish1)
    in
    let%bind () =
      section_hard
        "Wait for fish1 zkapp command with passing nonce check to be accepted \
         into transition frontier"
        (wait_for_zkapp ~has_failures:false valid_zkapp_cmd_from_fish1)
    in
    let%bind () =
      section_hard
        "Send zkapp commands with account updates for fish1 that sets send \
         permission to Proof and then tries to send funds "
        (send_zkapp_batch ~logger node
           [ set_permission_zkapp_cmd_from_fish1
           ; valid_fee_invalid_permission_zkapp_cmd_from_fish1
           ; invalid_fee_invalid_permission_zkapp_cmd_from_fish1
           ] )
    in
    let%bind () =
      section_hard
        "Wait for fish1 zkapp command with set permission to be accepted by \
         transition frontier"
        (wait_for_zkapp ~has_failures:false set_permission_zkapp_cmd_from_fish1)
    in
    let%bind () =
      section_hard
        "Wait for fish1 zkapp command that tries to send funds with Signature"
        (wait_for_zkapp ~has_failures:true
           valid_fee_invalid_permission_zkapp_cmd_from_fish1 )
    in
    let%bind () =
      section_hard
        "Verify account update after the updated permission failed by checking \
         account nonce"
        (let%bind { nonce = fish1_nonce; _ } =
           Network.Node.get_account_data ~logger node
             ~account_id:fish1_account_id
           |> Deferred.bind ~f:Malleable_error.or_hard_error
         in
         if Unsigned.UInt32.compare fish1_nonce (Unsigned.UInt32.of_int 4) > 0
         then
           Malleable_error.hard_error
             (Error.of_string
                "Nonce value of fish1 does not match expected nonce" )
         else (
           [%log info]
             "Invalid zkapp command was ignored as expected due to low fee" ;
           return () ) )
    in
    let%bind () =
      section_hard
        "Verify invalid zkapp commands are removed from transaction pool"
        (let%bind pooled_zkapp_commands =
           Network.Node.get_pooled_zkapp_commands ~logger node ~pk:fish1_pk
           |> Deferred.bind ~f:Malleable_error.or_hard_error
         in
         [%log debug] "Pooled zkapp_commands $commands"
           ~metadata:
             [ ( "commands"
               , `List (List.map ~f:(fun s -> `String s) pooled_zkapp_commands)
               )
             ] ;
         if List.is_empty pooled_zkapp_commands then (
           [%log info] "Transaction pool is empty" ;
           return () )
         else
           Malleable_error.hard_error
             (Error.of_string
                "Transaction pool contains invalid zkapp commands after a \
                 block was produced" ) )
    in
    let%bind () =
      (*wait for blocks required to produce 2 proofs given 0.75 slot fill rate + some buffer*)
      section_hard "Wait for proof to be emitted"
        ( wait_for t
        @@ Wait_condition.ledger_proofs_emitted_since_genesis
             ~test_config:config ~num_proofs )
    in
    Event_router.cancel (event_router t) snark_work_event_subscription () ;
    Event_router.cancel (event_router t) snark_work_failure_subscription () ;
    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           ( List.hd_exn
           @@ (Network.archive_nodes network |> Core.String.Map.data) )
       in
       check_replayer_logs ~logger logs )
end
