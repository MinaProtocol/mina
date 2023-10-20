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
      k = 2
    ; requires_graphql = true
    ; genesis_ledger =
        [ { account_name = "node-a-key"
          ; balance = "1000"
          ; timing = Untimed
          ; permissions = None
          ; zkapp = None
          }
        ; { account_name = "node-b-key"
          ; balance = "1000"
          ; timing = Untimed
          ; permissions = None
          ; zkapp = None
          }
        ; { account_name = "node-c-key"
          ; balance = "0"
          ; timing = Untimed
          ; permissions = None
          ; zkapp = None
          }
        ]
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ; { node_name = "node-c"; account_name = "node-c-key" }
        ]
    }

  (*
     There are 3 cases of bootstrap that we need to test:

     1: short bootstrap-- bootstrap where node has been down for less than 2k+1 blocks
     2: medium bootstrap-- bootstrap where node has been down for more than 2k+1 blocks, OR equivalently when the blockchain is longer than 2k+1 blocks and a node goes down and resets to a fresh state, thereby resetting at the genesis block, before reconnecting to the network
     3: long bootstrap-- bootstrap where node has been down for more than 42k slots (2 epochs) where each epoch emitted at least 1 parallel scan state proof
  *)

  (* this test is the medium bootstrap test *)

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_mina_nodes = Network.all_mina_nodes network in
    let%bind () =
      section_hard "Wait for nodes to initialize"
        (wait_for t
           (Wait_condition.nodes_to_initialize
              (Core.String.Map.data all_mina_nodes) ) )
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
    let%bind () =
      section_hard "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section_hard "restart node after 2k+1, ie 5, blocks"
        (let%bind () = Node.stop node_c in
         [%log info] "%s stopped, will now wait for blocks to be produced"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.blocks_to_be_produced 5) in
         let%bind () = Node.start ~fresh_state:true node_c in
         [%log info]
           "%s started again, will now wait for this node to initialize"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.node_to_initialize node_c) in
         wait_for t
           (Wait_condition.nodes_to_synchronize [ node_a; node_b; node_c ]) )
    in
    let%bind () =
      section_hard "network is fully connected after one node was restarted"
        (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
         let%bind final_connectivity_data =
           fetch_connectivity_data ~logger (Core.String.Map.data all_mina_nodes)
         in
         assert_peers_completely_connected final_connectivity_data )
    in
    let%bind () =
      section_hard "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    let%bind () =
      section_hard "restart node with the same state after 1 block"
        (let%bind () = Node.stop node_c in
         [%log info] "%s stopped, will now wait for blocks to be produced"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.blocks_to_be_produced 1) in
         let%bind () = Node.start ~fresh_state:false node_c in
         [%log info]
           "%s started again on same data, will now wait for this node to \
            initialize"
           (Node.id node_c) ;
         let%bind () =
           wait_for t
             (Wait_condition.transition_frontier_loaded_from_persistence
                ~fresh_data:false ~sync_needed:false )
         in
         let%bind () = wait_for t (Wait_condition.node_to_initialize node_c) in
         wait_for t
           (Wait_condition.nodes_to_synchronize [ node_a; node_b; node_c ]) )
    in

    section_hard "network is fully connected after one node was restarted"
      (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
       let%bind final_connectivity_data =
         fetch_connectivity_data ~logger (Core.String.Map.data all_mina_nodes)
       in
       assert_peers_completely_connected final_connectivity_data )
end
