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
        ; { balance = "1000"; timing = Untimed }
        ]
    ; num_snark_workers = 0
    }

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    (* let all_nodes = Network.block_producers network in *)
    let[@warning "-8"] [ node_a; node_b; node_c ] =
      Network.block_producers network
    in
    [%log info] "peers_list"
      ~metadata:
        [ ("peers", `List (List.map all_nodes ~f:(fun n -> `String (Node.id n))))
        ] ;
    (* TODO: let%bind () = wait_for t (Wait_condition.nodes_to_initialize [node_a; node_b; node_c]) in *)
    let%bind () =
      Malleable_error.List.iter all_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let%bind () =
      section "network is fully connected upon initialization"
        (Util.check_peers ~logger all_nodes)
    in
    (* let () =
         Out_channel.with_file "/tmp/network-graph.dot" ~f:(fun c ->
             G.output_graph c (graph_of_adjacency_list query_results) )
       in *)
    let%bind _ =
      section "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section "short bootstrap"
        (let%bind () = Node.stop node_c in
         [%log info] "%s stopped, will now wait for blocks to be produced"
           (Node.id node_c) ;
         let%bind _ = wait_for t (Wait_condition.blocks_to_be_produced 1) in
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
       Util.check_peers ~logger all_nodes)
end
