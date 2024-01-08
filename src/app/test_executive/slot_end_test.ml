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

  let num_extra_keys = 100

  let slot_tx_end = Mina_compile_config.slot_tx_end

  let slot_chain_end = Mina_compile_config.slot_chain_end

  let sender_account_prefix = "sender-account-"

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; genesis_ledger =
        [ { Test_Account.account_name = "receiver-key"
          ; balance = "9999999"
          ; timing = Untimed
          }
        ; { account_name = "sender-1-key"; balance = "0"; timing = Untimed }
        ; { account_name = "sender-2-key"; balance = "0"; timing = Untimed }
        ; { account_name = "sender-3-key"; balance = "0"; timing = Untimed }
        ; { account_name = "snark-node-key"; balance = "0"; timing = Untimed }
        ]
        @ List.init num_extra_keys ~f:(fun i ->
              { Test_Account.account_name =
                  sprintf "%s-%d" sender_account_prefix i
              ; balance = "1000"
              ; timing = Untimed
              } )
    ; block_producers =
        [ { node_name = "receiver"; account_name = "receiver-key" }
        ; { node_name = "sender-1"; account_name = "sender-1-key" }
        ; { node_name = "sender-2"; account_name = "sender-2-key" }
        ; { node_name = "sender-3"; account_name = "sender-3-key" }
        ]
    ; snark_coordinator =
        Some
          { node_name = "snark-node"
          ; account_name = "snark-node-key"
          ; worker_nodes = 4
          }
    ; txpool_max_size = 10_000_000
    ; snark_worker_fee = "0.0002"
    ; num_archive_nodes = 0
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.small
        }
    }

  let fee = Currency.Fee.of_int 10_000_000

  let amount = Currency.Amount.of_int 10_000_000

  let tx_delay_ms = 5000

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
      let receiver =
        String.Map.find_exn (Network.block_producers network) "receiver"
      in
      let%bind receiver_pub_key = pub_key_of_node receiver in
      let bp_senders =
        String.Map.remove (Network.block_producers network) "receiver"
        |> String.Map.data
      in
      let sender_kps =
        String.Map.fold (Network.genesis_keypairs network) ~init:[]
          ~f:(fun ~key ~data acc ->
            if String.is_prefix key ~prefix:sender_account_prefix then
              data :: acc
            else acc )
      in
      let sender_priv_keys =
        List.map sender_kps ~f:(fun kp -> kp.keypair.private_key)
      in
      let pk_to_string = Signature_lib.Public_key.Compressed.to_base58_check in
      [%log info] "receiver: %s" (pk_to_string receiver_pub_key) ;
      let%bind () =
        Malleable_error.List.iter sender_kps ~f:(fun s ->
            let pk =
              s.keypair.public_key |> Signature_lib.Public_key.compress
            in
            return ([%log info] "sender: %s" (pk_to_string pk)) )
      in
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
           let num_sender_keys = List.length sender_priv_keys in
           let n_bp_senders = List.length bp_senders in
           let keys_per_sender = num_sender_keys / n_bp_senders in
           [%log info]
             "will now send %d payments from as many accounts. %d nodes will \
              send %d payments each from distinct keys"
             num_payments n_bp_senders keys_per_sender ;
           Malleable_error.List.fold ~init:sender_priv_keys bp_senders
             ~f:(fun keys node ->
               let keys0, rest = List.split_n keys keys_per_sender in
               Integration_test_lib.Graphql_requests.must_send_test_payments
                 ~repeat_count ~repeat_delay_ms ~logger ~senders:keys0
                 ~receiver_pub_key ~amount ~fee
                 (Network.Node.get_ingress_uri node)
               >>| const rest )
           >>| const () )
      in
      let%bind () =
        section
          (Printf.sprintf "wait until slot %d" num_slots)
          Async.(at end_t >>= const Malleable_error.ok_unit)
      in
      let ok_if_true s =
        Malleable_error.ok_if_true ~error:(Error.of_string s) ~error_type:`Soft
      in
      let%bind blocks =
        Integration_test_lib.Graphql_requests
        .must_get_best_chain_for_slot_end_test ~max_length:(2 * num_slots)
          ~logger
          (Network.Node.get_ingress_uri receiver)
      in
      let%bind () =
        section "blocks produced before slot_tx_end"
          ( ok_if_true "only empty blocks were produced before slot_tx_end"
          @@ List.exists blocks ~f:(fun block ->
                 Option.value_map slot_tx_end ~default:true
                   ~f:(fun slot_tx_end ->
                     Mina_numbers.Global_slot.(
                       of_uint32 block.slot_since_genesis < slot_tx_end) )
                 && ( block.command_transaction_count <> 0
                    || block.snark_work_count <> 0
                    || block.coinbase <> 0 ) ) )
      in
      let%bind () =
        section "blocks produced after slot_tx_end"
          (Option.value_map slot_tx_end ~default:Malleable_error.ok_unit
             ~f:(fun slot_tx_end ->
               Malleable_error.List.iter blocks ~f:(fun block ->
                   let msg =
                     Printf.sprintf
                       "non-empty block after slot_tx_end. block slot since \
                        genesis: %s, txn count: %d, snark work count: %d, \
                        coinbase: %d"
                       (Mina_numbers.Global_slot.to_string
                          block.slot_since_genesis )
                       block.command_transaction_count block.snark_work_count
                       block.coinbase
                   in
                   ok_if_true msg
                     ( Mina_numbers.Global_slot.(
                         of_uint32 block.slot_since_genesis < slot_tx_end)
                     || block.command_transaction_count = 0
                        && block.snark_work_count = 0 && block.coinbase = 0 ) ) )
          )
      in
      let%bind () =
        section "blocks produced before slot_chain_end"
          ( ok_if_true "no block produced before slot_chain_end"
          @@ List.exists blocks ~f:(fun block ->
                 Option.value_map slot_chain_end ~default:true
                   ~f:(fun slot_chain_end ->
                     Mina_numbers.Global_slot.(
                       of_uint32 block.slot_since_genesis < slot_chain_end) ) )
          )
      in
      section "no blocks produced after slot_chain_end"
        (Option.value_map slot_chain_end ~default:Malleable_error.ok_unit
           ~f:(fun slot_chain_end ->
             ok_if_true "blocks produced after slot_chain_end"
             @@ not
             @@ List.exists blocks ~f:(fun block ->
                    Mina_numbers.Global_slot.(
                      of_uint32 block.slot_since_genesis >= slot_chain_end) ) )
        )
end
