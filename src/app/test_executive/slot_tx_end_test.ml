open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let _num_extra_keys = 1000

  let slot_tx_end = Mina_compile_config.slot_tx_end

  let slot_chain_end = Mina_compile_config.slot_chain_end

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; genesis_ledger =
        [ { Test_Account.account_name = "bp-1-key"
          ; balance = "9999999"
          ; timing = Untimed
          }
        ; { account_name = "bp-2-key"; balance = "9999999"; timing = Untimed }
        ; { account_name = "snark-node-key"; balance = "0"; timing = Untimed }
        ; { account_name = "receiver-key"; balance = "0"; timing = Untimed }
        ; { account_name = "sender-key"; balance = "9999999"; timing = Untimed }
        ; { account_name = "fish-key"; balance = "100"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "bp-1"; account_name = "bp-1-key" }
        ; { node_name = "bp-2"; account_name = "bp-2-key" }
        ; { node_name = "fish"; account_name = "fish-key" }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
          ; worker_nodes = 4
          }
    ; txpool_max_size = 10_000_000
    ; snark_worker_fee = "0.0001"
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  let fee = Currency.Fee.of_int 10_000_000

  let amount = Currency.Amount.of_int 10_000_000

  let tx_delay_ms = 500

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    if Option.is_none slot_tx_end && Option.is_none slot_chain_end then (
      [%log info]
        "slot_tx_end and slot_chain_end are both None. This test doesn't apply." ;
      Malleable_error.ok_unit )
    else
      let num_slots =
        match (slot_tx_end, slot_chain_end) with
        | None, None ->
            assert false
        | Some slot, None | None, Some slot | Some _, Some slot ->
            Mina_numbers.Global_slot.to_int slot + 5
      in
      let fish = String.Map.find_exn (Network.block_producers network) "fish" in
      let%bind fish_pub_key = pub_key_of_node fish in
      let fish_kp =
        String.Map.find_exn (Network.genesis_keypairs network) "sender-key"
      in
      let fish_priv_key = fish_kp.keypair.private_key in
      let window_ms =
        (Network.constraint_constants network).block_window_duration_ms
      in
      let all_nodes = Network.all_nodes network in
      let%bind () =
        wait_for t
          (Wait_condition.nodes_to_initialize (String.Map.data all_nodes))
      in
      let%bind () =
        section_hard "wait for 3 blocks to be produced (warm-up)"
          (wait_for t (Wait_condition.blocks_to_be_produced 3))
      in
      let end_t =
        Time.add (Time.now ())
          (Time.Span.of_ms @@ float_of_int (num_slots * window_ms))
      in
      let%bind () =
        section_hard "spawn transaction sending"
          (let num_payments = num_slots * window_ms / tx_delay_ms in
           let repeat_count = Unsigned.UInt32.of_int num_payments in
           let repeat_delay_ms = Unsigned.UInt32.of_int tx_delay_ms in
           let keys_per_sender = 1 in
           [%log info]
             "will now send %d payments from as many accounts.  %d nodes will \
              send %d payments each from distinct keys"
             num_payments 1 keys_per_sender ;
           Integration_test_lib.Graphql_requests.must_send_test_payments
             ~repeat_count ~repeat_delay_ms ~logger ~senders:[ fish_priv_key ]
             ~receiver_pub_key:fish_pub_key ~amount ~fee
             (Network.Node.get_ingress_uri fish) )
      in
      let%bind () =
        section "wait for payments to be processed"
          Async.(at end_t >>= const Malleable_error.ok_unit)
      in
      (* let event_router = event_router t in
         let event_subscription =
           Event_router.on event_router Block_produced
             ~f:(fun
                  node
                  { Event_type.Block_produced.block_height
                  ; epoch
                  ; global_slot
                  ; snarked_ledger_generated
                  ; state_hash
                  }
                ->
               [%log info] "block produced" ;
               Async.Deferred.return `Continue )
         in
         Async.Deferred.Let_syntax.let%bind () =
           Event_router.await event_router event_subscription
         in *)
      let ok_if_true s =
        Malleable_error.ok_if_true ~error:(Error.of_string s) ~error_type:`Soft
      in

      section "checked produced blocks"
        (let%bind blocks =
           Integration_test_lib.Graphql_requests
           .must_get_best_chain_for_slot_end_test ~max_length:(2 * num_slots)
             ~logger
             (Network.Node.get_ingress_uri fish)
         in
         let%bind () =
           Malleable_error.List.iter blocks ~f:(fun block ->
               let%bind () =
                 Option.value_map slot_tx_end ~default:Malleable_error.ok_unit
                   ~f:(fun slot_tx_end ->
                     ok_if_true "block with transactions after slot_tx_end"
                       ( Mina_numbers.Global_slot.(
                           of_uint32 block.slot_since_genesis < slot_tx_end)
                       || block.command_transaction_count = 0
                          && block.snark_work_count = 0 && block.coinbase = 0 ) )
               in
               Option.value_map slot_chain_end ~default:Malleable_error.ok_unit
                 ~f:(fun slot_chain_end ->
                   ok_if_true "block produced for slot after slot_chain_end"
                     Mina_numbers.Global_slot.(
                       of_uint32 block.slot_since_genesis < slot_chain_end) ) )
         in
         ok_if_true "" true )
end
