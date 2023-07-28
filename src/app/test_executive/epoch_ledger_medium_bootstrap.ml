open Core
open Async
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

  let config =
    let k = 2 in

    let open Test_config in
    { default with
      k
    ; slots_per_epoch = 3 * 8 * k
    ; requires_graphql = true
    ; genesis_ledger =
        [ { account_name = "node-a-key"; balance = "1000"; timing = Untimed }
        ; { account_name = "node-b-key"; balance = "1000"; timing = Untimed }
        ; { account_name = "node-c-key"; balance = "0"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ; { node_name = "node-c"; account_name = "node-c-key" }
        ]
    ; proof_config =
        { proof_config_default with
          work_delay = Some 1
        ; transaction_capacity =
            Some Runtime_config.Proof_keys.Transaction_capacity.medium
        }
    }

  let transactions_sent = ref 0

  let num_proofs = 2

  let run network t =
    let slot_ms =
      Option.value_exn config.proof_config.block_window_duration_ms
    in
    (* time for 1 epoch *)
    let epoch_ms = config.slots_per_epoch * slot_ms |> Float.of_int in
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let block_producer_nodes =
      Network.block_producers network |> Core.String.Map.data
    in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize (Core.String.Map.data all_nodes))
    in
    let node_a =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let node_b =
      Core.String.Map.find_exn (Network.block_producers network) "node-b"
    in
    let node_c =
      Core.String.Map.find_exn (Network.block_producers network) "node-c"
    in
    let start_time = Time.now () in
    let%bind () =
      section "send out padding transactions"
        (let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
         send_padding_transactions block_producer_nodes ~fee ~logger
           ~n:(2 * padding_payments ~transactions_sent ~num_proofs ~config) )
    in
    let%bind () =
      section "wait for a ledger proof being emitted"
        (wait_for t
           (Wait_condition.ledger_proofs_emitted_since_genesis ~num_proofs:1
              ~test_config:config ) )
    in
    let%bind () = section "stop the node" (Node.stop node_c) in
    let%bind () =
      section
        "Wait for one epoch, and make sure the next epoch ledger has been \
         updated"
        (let%bind () =
           let current_time = Time.now () in
           Malleable_error.lift
             (Async.after
                Time.Span.(of_ms epoch_ms - Time.(diff current_time start_time)) )
         in
         wait_for t (Wait_condition.next_epoch_ledger_updated ()) )
    in
    let%bind () =
      section
        "Wait for another epoch, and make sure that the staking epoch ledger \
         has been updated"
        (let%bind () =
           Malleable_error.lift (Async.after (Time.Span.of_ms epoch_ms))
         in
         wait_for t (Wait_condition.staking_epoch_ledger_updated ()) )
    in
    let%bind () =
      section "restart node after 2 epochs"
        (let%bind () = Node.start ~fresh_state:true node_c in
         [%log info]
           "%s started again, will now wait for this node to initialize"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.node_to_initialize node_c) in
         wait_for t
           (Wait_condition.nodes_to_synchronize [ node_a; node_b; node_c ]) )
    in

    section "network is fully connected after one node was restarted"
      (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
       let%bind final_connectivity_data =
         fetch_connectivity_data ~logger (Core.String.Map.data all_nodes)
       in
       assert_peers_completely_connected final_connectivity_data )
end
