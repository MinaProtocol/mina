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

  let num_extra_keys = 1000

  (* let num_sender_nodes = 4 *)

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; genesis_ledger =
        [ { Test_Account.account_name = "receiver-key"
          ; balance = "9999999"
          ; timing = Untimed
          }
        ; { account_name = "empty-bp-key"; balance = "0"; timing = Untimed }
        ; { account_name = "snark-node-key"; balance = "0"; timing = Untimed }
        ]
        @ List.init num_extra_keys ~f:(fun i ->
              let i_str = Int.to_string i in
              { Test_Account.account_name =
                  String.concat [ "sender-account"; i_str ]
              ; balance = "10000"
              ; timing = Untimed
              } )
    ; block_producers =
        [ { node_name = "receiver"; account_name = "receiver-key" }
        ; { node_name = "empty_node-1"; account_name = "empty-bp-key" }
        ; { node_name = "empty_node-2"; account_name = "empty-bp-key" }
        ; { node_name = "empty_node-3"; account_name = "empty-bp-key" }
        ; { node_name = "empty_node-4"; account_name = "empty-bp-key" }
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

  let num_slots = 15

  let min_resulting_blocks = 12

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let receiver =
      Core.String.Map.find_exn (Network.block_producers network) "receiver"
    in
    let%bind receiver_pub_key = pub_key_of_node receiver in
    let empty_bps =
      Core.String.Map.remove (Network.block_producers network) "receiver"
      |> Core.String.Map.data
    in
    let rec map_remove_keys map ~(keys : string list) =
      match keys with
      | [] ->
          map
      | hd :: tl ->
          map_remove_keys (Core.String.Map.remove map hd) ~keys:tl
    in
    let sender_kps =
      map_remove_keys
        (Network.genesis_keypairs network)
        ~keys:[ "receiver-key"; "empty-bp-key"; "snark-node-key" ]
      |> Core.String.Map.data
    in
    let sender_priv_keys =
      List.map sender_kps ~f:(fun kp -> kp.keypair.private_key)
    in
    let pk_to_string = Signature_lib.Public_key.Compressed.to_base58_check in
    [%log info] "receiver: %s" (pk_to_string receiver_pub_key) ;
    let%bind () =
      Malleable_error.List.iter sender_kps ~f:(fun s ->
          let pk = s.keypair.public_key |> Signature_lib.Public_key.compress in
          return ([%log info] "sender: %s" (pk_to_string pk)) )
    in
    let window_ms =
      (Network.constraint_constants network).block_window_duration_ms
    in
    let all_nodes = Network.all_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize (Core.String.Map.data all_nodes))
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
         let keys_per_sender = num_sender_keys / List.length empty_bps in
         [%log info]
           "will now send %d payments from as many accounts.  %d nodes will \
            send %d payments each from distinct keys"
           num_payments (List.length empty_bps) keys_per_sender ;
         Malleable_error.List.fold ~init:sender_priv_keys empty_bps
           ~f:(fun keys node ->
             let keys0, rest = List.split_n keys keys_per_sender in
             Network.Node.must_send_test_payments ~repeat_count ~repeat_delay_ms
               ~logger ~senders:keys0 ~receiver_pub_key ~amount ~fee node
             >>| const rest )
         >>| const () )
    in
    let%bind () =
      section "wait for payments to be processed"
        Async.(at end_t >>= const Malleable_error.ok_unit)
    in
    let ok_if_true s =
      Malleable_error.ok_if_true ~error:(Error.of_string s) ~error_type:`Soft
    in
    let%bind () =
      section "checked produced blocks"
        (let%bind blocks =
           Network.Node.must_get_best_chain ~logger ~max_length:(2 * num_slots)
             receiver
         in
         let%bind () =
           ok_if_true "not enough blocks"
             (List.length blocks >= min_resulting_blocks)
         in
         let tx_counts =
           Array.of_list
           @@ List.drop_while ~f:(( = ) 0)
           @@ List.map ~f:(fun b -> b.command_transaction_count) blocks
         in
         Array.sort ~compare tx_counts ;
         let non_zero_tx_counts = Array.length tx_counts in
         let tx_counts_med =
           ( tx_counts.(non_zero_tx_counts / 2)
           + tx_counts.((non_zero_tx_counts - 1) / 2) )
           / 2
         in
         let res_num_payments = Array.fold ~init:0 ~f:( + ) tx_counts in
         [%log info] "Total %d payments in blocks, see $blocks for details"
           res_num_payments
           ~metadata:
             [ ( "blocks"
               , `List
                   (List.map blocks ~f:(fun b ->
                        `Tuple
                          [ `String b.state_hash
                          ; `Int b.command_transaction_count
                          ; `String b.creator_pk
                          ] ) ) )
             ] ;
         (* TODO Use protocol constants to derive 125 *)
         ok_if_true "blocks are not full (median test)" (tx_counts_med = 125) )
    in
    let get_metrics node =
      Async_kernel.Deferred.bind
        (Network.Node.get_metrics ~logger node)
        ~f:Malleable_error.or_hard_error
    in
    let%bind () =
      section "check metrics of tx receiver node"
        (let%bind { block_production_delay = rcv_delay; _ } =
           get_metrics receiver
         in
         let rcv_delay_rest =
           List.fold ~init:0 ~f:( + ) @@ List.drop rcv_delay 1
         in
         (* First two slots might be delayed because of test's bootstrap, so we have 2 as a threshold *)
         ok_if_true "block production was delayed" (rcv_delay_rest <= 2) )
    in
    section "retrieve metrics of tx sender nodes"
      (* We omit the result because we just want to query the txn sending nodes to see some useful
          output in test logs *)
      (Malleable_error.List.iter empty_bps
         ~f:
           (Fn.compose Malleable_error.soften_error
              (Fn.compose Malleable_error.ignore_m get_metrics) ) )
end
