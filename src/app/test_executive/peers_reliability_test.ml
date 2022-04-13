open Core
open Async
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
    let open Test_config.Block_producer in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "1000"; timing = Untimed }
        ; { balance = "1000"; timing = Untimed }
        ; { balance = "0"; timing = Untimed }
        ]
    ; num_snark_workers = 0
    }

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    [%log info] "peers_list"
      ~metadata:
        [ ("peers", `List (List.map all_nodes ~f:(fun n -> `String (Node.id n))))
        ] ;
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ node_a; node_b; node_c ] =
      Network.block_producers network
    in
    let%bind initial_connectivity_data =
      Util.fetch_connectivity_data ~logger all_nodes
    in
    let%bind () =
      section "network is fully connected upon initialization"
        (Util.assert_peers_completely_connected initial_connectivity_data)
    in
    let%bind () =
      section
        "network can't be paritioned if 2 nodes are hypothetically taken \
         offline"
        (Util.assert_peers_cant_be_partitioned ~max_disconnections:2
           initial_connectivity_data)
    in
    let%bind _ =
      section "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section "short bootstrap"
        (let%bind () = Node.stop node_c in
         [%log info] "%s stopped, will now wait for blocks to be produced"
           (Node.id node_c) ;
         let%bind _ =
           wait_for t
             ( Wait_condition.blocks_to_be_produced 1
             (* Extend the wait timeout, only 2/3 of stake is online. *)
             |> Wait_condition.with_timeouts
                  ~soft_timeout:(Network_time_span.Slots 3)
                  ~hard_timeout:(Network_time_span.Slots 6) )
         in
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
                     (Time.Span.of_ms (15. *. 60. *. 1000.))) ))
    in
    section "network is fully connected after one node was restarted"
      (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
       let%bind final_connectivity_data =
         Util.fetch_connectivity_data ~logger all_nodes
       in
       Util.assert_peers_completely_connected final_connectivity_data)
end
