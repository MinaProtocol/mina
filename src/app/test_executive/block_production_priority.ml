open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; block_producers =
        (let open Block_producer in
        [ { balance = "9999999"; timing = Untimed } (* Two senders *)
        ; { balance = "0"; timing = Untimed }
        ; { balance = "0"; timing = Untimed }
        ; { balance = "0"; timing = Untimed }
        ; { balance = "0"; timing = Untimed }
        ; { balance = "0"; timing = Untimed }
        ])
    ; num_snark_workers = 0
    ; aux_account_balance = Some "1000"
    ; txpool_max_size = 10_000_000
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "starting..." ;
    (* let%bind () = wait_for_bps_to_initialize ~logger network t in *)
    let all_nodes = Network.all_nodes network in
    let%bind all_peerids =
      Malleable_error.List.map all_nodes
        ~f:(Network.Node.must_get_peer_id ~logger)
      >>| List.map ~f:fst
    in
    let trusted_peers =
      List.map all_peerids ~f:(fun peer_id ->
          { Network_peer.Peer.peer_id
          ; host = Unix.Inet_addr.of_string "127.0.0.1"
          ; libp2p_port = 8888
          })
    in
    let%bind () =
      Malleable_error.List.iter all_nodes
        ~f:
          (Network.Node.must_set_connection_gating_config ~logger ~trusted_peers
             ~isolate:false ~banned_peers:[])
    in
    let%bind () =
      Malleable_error.List.iter all_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    [%log info] "done waiting for initializations" ;
    let%bind receiver, senders =
      match Network.block_producers network with
      | [] ->
          Malleable_error.hard_error_string "no block producers"
      | r :: rs ->
          return (r, rs)
    in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver in
    (* let sender_bp = List.nth_exn bps 1 in *)
    (* let%bind sender_pub_key = Util.pub_key_of_node sender_bp in *)
    let pk_to_string = Signature_lib.Public_key.Compressed.to_base58_check in
    [%log info] "receiver: %s" (pk_to_string receiver_pub_key) ;
    let%bind () =
      Malleable_error.List.iter senders ~f:(fun s ->
          let%map pk = Util.pub_key_of_node s in
          [%log info] "sender: %s" (pk_to_string pk))
    in
    let tps = 1 in
    let window_ms =
      (Network.constraint_constants network).block_window_duration_ms
    in
    let num_slots = 10 in
    let num_payments = tps * num_slots * window_ms / 1000 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let amount = Currency.Amount.of_int 10_000_000 in
    [%log info] "will now send %d payments" num_payments ;
    let get_metrics node =
      Async_kernel.Deferred.bind
        (Network.Node.get_metrics ~logger node)
        ~f:Malleable_error.or_hard_error
    in
    let%bind () = wait_for t (Wait_condition.blocks_to_be_produced 3) in
    (* check account nonce on both nodes *)
    let end_t =
      Time.add (Time.now ())
        (Time.Span.of_ms @@ float_of_int (num_slots * window_ms))
    in
    let num_senders = List.length senders in
    let sender_keys =
      List.map ~f:snd
      @@ List.drop
           (Array.to_list @@ Lazy.force @@ Mina_base.Sample_keypairs.keypairs)
           (num_senders + 2)
    in
    let num_sender_keys = List.length sender_keys in
    let keys_per_sender = num_sender_keys / num_senders in
    let%bind () =
      Malleable_error.ok_if_true ~error_type:`Hard
        ~error:(Error.of_string "not enough sender keys")
        (keys_per_sender > 0)
    in
    let repeat_count = Unsigned.UInt32.of_int num_payments in
    let repeat_delay_ms = Unsigned.UInt32.of_int (1000 / tps) in
    let%bind _ =
      Malleable_error.List.fold ~init:sender_keys senders ~f:(fun keys node ->
          let keys0, rest = List.split_n keys keys_per_sender in
          Network.Node.must_send_test_payments ~repeat_count ~repeat_delay_ms
            ~logger ~senders:keys0 ~receiver_pub_key ~amount ~fee node
          >>| const rest)
    in
    let%bind () = Async.(at end_t >>= const Malleable_error.ok_unit) in
    let%bind blocks =
      Network.Node.must_get_best_chain ~logger ~max_length:(2 * num_slots)
        receiver
    in
    let res_num_payments, _ =
      List.fold_map blocks ~init:0 ~f:(fun s b ->
          (s + b.command_transaction_count, ()))
    in
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
                     ])) )
        ] ;
    let%bind { block_production_delay = rcv_delay; _ } = get_metrics receiver in
    (* We omit the result because we just want to query senders to see some useful
       output in test logs *)
    let%bind () =
      Malleable_error.List.iter senders
        ~f:
          (Fn.compose Malleable_error.soften_error
             (Fn.compose Malleable_error.ignore_m get_metrics))
    in
    let rcv_delay0 = List.nth_exn rcv_delay 0 in
    let%map () =
      Malleable_error.ok_if_true
        ~error:(Error.of_string "unexpected block production delays")
        ( (* Check that testing tps was actually realized (at least in half) into
             transactions that got to blocks *)
          res_num_payments * 2 > num_payments
        (* Check that there were no short forks *)
        && rcv_delay0 <= List.length blocks
        (* Check that most of blocks got to the first delay bucket
           (were produced within a minute) *)
        && rcv_delay0 >= num_slots - 1 )
    in
    [%log info] "block_production_priority test: test finished!!"
end
