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
    let open Test_config in
    { default with
      requires_graphql = true
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
    }

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    [%log info] "peers_list"
      ~metadata:
        [ ( "peers"
          , `List
              (List.map (Core.String.Map.data all_nodes) ~f:(fun n ->
                   `String (Node.id n) ) ) )
        ] ;
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

    let online_monitor, online_monitor_subscription =
      Wait_condition.monitor_online_nodes ~logger (event_router t)
    in
    (* The nodes that we synchronize to must be online. *)
    Wait_condition.require_online online_monitor node_a ;
    Wait_condition.require_online online_monitor node_b ;

    let%bind initial_connectivity_data =
      fetch_connectivity_data ~logger (Core.String.Map.data all_nodes)
    in
    let%bind () =
      section "network is fully connected upon initialization"
        (assert_peers_completely_connected initial_connectivity_data)
    in
    let%bind () =
      section
        "network can't be paritioned if 2 nodes are hypothetically taken \
         offline"
        (assert_peers_cant_be_partitioned ~max_disconnections:2
           initial_connectivity_data )
    in
    let%bind () =
      section "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section "short bootstrap"
        (let%bind () = Node.stop node_c in
         [%log info] "%s stopped, will now wait for blocks to be produced"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.blocks_to_be_produced 1) in
         let%bind () = Node.start ~fresh_state:true node_c in
         [%log info]
           "%s started again, will now wait for this node to initialize"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.node_to_initialize node_c) in
         wait_for t
           ( Wait_condition.nodes_to_synchronize [ node_a; node_b; node_c ]
           |> Wait_condition.with_timeouts
                ~hard_timeout:
                  (Network_time_span.Literal
                     (Time.Span.of_ms (15. *. 60. *. 1000.)) ) ) )
    in
    let%bind () =
      section "network is fully connected after one node was restarted"
        (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
         let%bind final_connectivity_data =
           fetch_connectivity_data ~logger (Core.String.Map.data all_nodes)
         in
         assert_peers_completely_connected final_connectivity_data )
    in
    return (Event_router.cancel (event_router t) online_monitor_subscription ())
end
