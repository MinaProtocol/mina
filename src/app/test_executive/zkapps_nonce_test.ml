open Core
open Async
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "8000000000"; timing = Untimed }
        ; { balance = "1000000000"; timing = Untimed }
        ]
    ; extra_genesis_accounts =
        [ { balance = "3000"; timing = Untimed }
        ; { balance = "3000"; timing = Untimed }
        ]
    ; num_archive_nodes = 1
    ; num_snark_workers = 2
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  let transactions_sent = ref 0

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
    let%bind sender_pub_key = Util.pub_key_of_node sender in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver in
    repeat_seq ~n ~f:(fun () ->
        Network.Node.must_send_payment ~logger sender ~sender_pub_key
          ~receiver_pub_key ~amount:Currency.Amount.one ~fee
        >>| ignore )

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let node = List.hd_exn block_producer_nodes in
    let[@warning "-8"] [ fish1_kp; fish2_kp ] =
      Network.extra_genesis_keypairs network
    in
    let fish1_pk = Signature_lib.Public_key.compress fish1_kp.public_key in
    let fish2_pk = Signature_lib.Public_key.compress fish2_kp.public_key in
    let with_timeout =
      let soft_slots = 3 in
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let wait_for_zkapp ~has_failures zkapp_command =
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures
             ~zkapp_command
      in
      [%log info] "zkApp transaction included in transition frontier"
    in
    let%bind () =
      section_hard "Wait for nodes to initialize"
        (wait_for t
           (Wait_condition.nodes_to_initialize
              ( Network.seeds network @ block_producer_nodes
              @ Network.snark_coordinators network ) ) )
    in
    let keymap =
      List.fold [ fish1_kp; fish2_kp ]
        ~init:Signature_lib.Public_key.Compressed.Map.empty
        ~f:(fun map { private_key; public_key } ->
          Signature_lib.Public_key.Compressed.Map.add_exn map
            ~key:(Signature_lib.Public_key.compress public_key)
            ~data:private_key )
    in
    let%bind.Deferred invalid_nonce_transaction_from_fish1 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature Call fish1_kp Token_id.default
                   0 ~increment_nonce:true
                   ~preconditions:
                     { Account_update.Preconditions.network =
                         Zkapp_precondition.Protocol_state.accept
                     ; account = Nonce (Account.Nonce.of_int 1)
                     } )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"invalid transaction from fish1"
             ~fee:12_000_000 ~fee_payer_pk:fish1_pk
             ~fee_payer_nonce:(Account.Nonce.of_int 0)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    let%bind.Deferred valid_nonce_transaction_from_fish1 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature Call fish1_kp Token_id.default
                   0 ~increment_nonce:true
                   ~preconditions:
                     { Account_update.Preconditions.network =
                         Zkapp_precondition.Protocol_state.accept
                     ; account = Nonce (Account.Nonce.of_int 2)
                     } )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"valid transaction from fish1" ~fee:12_000_000
             ~fee_payer_pk:fish1_pk ~fee_payer_nonce:(Account.Nonce.of_int 1)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    let%bind.Deferred invalid_nonce_transaction_from_fish2 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature Call fish2_kp Token_id.default
                   0 ~increment_nonce:true
                   ~preconditions:
                     { Account_update.Preconditions.network =
                         Zkapp_precondition.Protocol_state.accept
                     ; account = Nonce (Account.Nonce.of_int 1)
                     } )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"invalid transaction from fish2"
             ~fee:12_000_000 ~fee_payer_pk:fish2_pk
             ~fee_payer_nonce:(Account.Nonce.of_int 0)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    let%bind.Deferred valid_nonce_transaction_from_fish2 =
      let open Zkapp_command_builder in
      let with_dummy_signatures =
        let account_updates =
          mk_forest
            [ mk_node
                (mk_account_update_body Signature Call fish2_kp Token_id.default
                   0 ~increment_nonce:true
                   ~preconditions:
                     { Account_update.Preconditions.network =
                         Zkapp_precondition.Protocol_state.accept
                     ; account = Nonce (Account.Nonce.of_int 2)
                     } )
                []
            ]
        in
        account_updates
        |> mk_zkapp_command ~memo:"valid transaction from fish2" ~fee:12_000_000
             ~fee_payer_pk:fish2_pk ~fee_payer_nonce:(Account.Nonce.of_int 1)
      in
      replace_authorizations ~keymap with_dummy_signatures
    in
    let%bind () =
      section
        "Send a zkapp command with an invalid account update nonce using fish1"
        (send_zkapp ~logger node invalid_nonce_transaction_from_fish1)
    in
    let%bind () =
      section
        "Send a zkapp command with an invalid account update nonce using fish2"
        (send_zkapp ~logger node invalid_nonce_transaction_from_fish2)
    in
    let%bind () =
      section
        "Send a zkapp command that has it's nonce properly incremented after \
         the fish1 transaction"
        (send_zkapp ~logger node valid_nonce_transaction_from_fish1)
    in
    let%bind () =
      section
        "Send a zkapp command that has it's nonce properly incremented after \
         the fish2 transaction"
        (send_zkapp ~logger node valid_nonce_transaction_from_fish2)
    in
    let%bind () =
      section
        "Wait for fish1 zkapp command with invalid nonce to be rejected by \
         transition frontier"
        (wait_for_zkapp ~has_failures:true invalid_nonce_transaction_from_fish1)
    in
    let%bind () =
      section
        "Wait for fish2 zkapp command with invalid nonce to be rejected by \
         transition frontier"
        (wait_for_zkapp ~has_failures:true invalid_nonce_transaction_from_fish2)
    in
    let%bind () =
      section
        "Wait for fish1 zkapp command with valid nonce to be accepted by \
         transition frontier"
        (wait_for_zkapp ~has_failures:false valid_nonce_transaction_from_fish1)
    in
    let%bind () =
      section
        "Wait for fish2 zkapp command with valid nonce to be accepted by \
         transition frontier"
        (wait_for_zkapp ~has_failures:false valid_nonce_transaction_from_fish2)
    in
    let%bind () =
      let padding_payments =
        (* for work_delay=1 and transaction_capacity=4 per block*)
        let needed = 36 in
        if !transactions_sent >= needed then 0 else needed - !transactions_sent
      in
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      send_padding_transactions block_producer_nodes ~fee ~logger
        ~n:padding_payments
    in
    let%bind () =
      section_hard "wait for 1 block to be produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section "Verify invalid zkapp commands are removed from transaction pool"
        (let%bind pooled_zkapp_commands =
           Network.Node.get_pooled_zkapp_commands ~logger node ~pk:fish1_pk
           |> Deferred.bind ~f:Malleable_error.or_hard_error
         in
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
      section_hard "Wait for proof to be emitted"
        (wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:2) )
    in
    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ Network.archive_nodes network)
       in
       check_replayer_logs ~logger logs )
end
