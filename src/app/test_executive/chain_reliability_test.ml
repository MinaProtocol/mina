open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  let test_name = "chain-reliability"

  let config =
    let open Test_config in
    { default with
      genesis_ledger =
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
    let%bind _ =
      section "blocks are produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 2))
    in
    let%bind () =
      section "short bootstrap"
        (let%bind () = Node.stop node_c in
         [%log info] "%s stopped, will now wait for blocks to be produced"
           (Node.id node_c) ;
         let%bind _ = wait_for t (Wait_condition.blocks_to_be_produced 2) in
         let%bind () = Node.start ~fresh_state:true node_c in
         [%log info]
           "%s started again, will now wait for this node to initialize"
           (Node.id node_c) ;
         let%bind () = wait_for t (Wait_condition.node_to_initialize node_c) in
         wait_for t
           ( Wait_condition.nodes_to_synchronize [ node_a; node_b; node_c ]
           |> Wait_condition.with_timeouts
                ~soft_timeout:(Network_time_span.Slots 3)
                ~hard_timeout:
                  (Network_time_span.Literal
                     (Time.Span.of_ms (15. *. 60. *. 1000.)) ) ) )
    in
    let print_chains (labeled_chain_list : (string * string list) list) =
      List.iter labeled_chain_list ~f:(fun labeled_chain ->
          let label, chain = labeled_chain in
          let chain_str = String.concat ~sep:"\n" chain in
          [%log info] "\nchain of %s:\n %s" label chain_str )
    in
    let%bind () =
      section
        "set up for checking for shared state, send a several payments and \
         wait for them to be added to chain"
        (let receiver_bp = node_a in
         let%bind receiver_pub_key = pub_key_of_node receiver_bp in
         let sender_bp = node_b in
         let%bind sender_pub_key = pub_key_of_node sender_bp in
         let num_payments = 3 in
         let amount = Currency.Amount.of_mina_string_exn "10" in
         let fee = Currency.Fee.of_mina_string_exn "1" in
         [%log info] "chain_reliability_test: will now send %d payments"
           num_payments ;
         let%bind hashlist =
           send_payments ~logger ~sender_pub_key ~receiver_pub_key
             ~node:sender_bp ~fee ~amount num_payments
         in
         [%log info]
           "chain_reliability_test: sending payments done. will now wait for \
            payments" ;
         let%map () = wait_for_payments ~logger ~dsl:t ~hashlist num_payments in
         [%log info] "chain_reliability_test: finished waiting for payments" ;
         () )
    in
    section "common prefix of all nodes is no farther back than 1 block"
      (* the common prefix test relies on at least 4 blocks having been produced.  previous sections altogether have already produced 4, so no further block production is needed.  if previous sections change, then this may need to be re-adjusted*)
      (let%bind (labeled_chains : (string * string list) list) =
         Malleable_error.List.map (Core.String.Map.data all_nodes)
           ~f:(fun node ->
             let%map chain = Network.Node.must_get_best_chain ~logger node in
             (Node.id node, List.map ~f:(fun b -> b.state_hash) chain) )
       in
       let (chains : string list list) =
         List.map labeled_chains ~f:(fun (_, chain) -> chain)
       in
       print_chains labeled_chains ;
       check_common_prefixes chains ~tolerance:1 ~logger )
end
