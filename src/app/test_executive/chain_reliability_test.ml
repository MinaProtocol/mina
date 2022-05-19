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
    let open Test_config.Wallet in
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
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ node_a; node_b; node_c ] =
      Network.block_producers network
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
    section "common prefix of all nodes is no farther back than 1 block"
      (* the common prefix test relies on at least 4 blocks having been produced.  previous sections altogether have already produced 4, so no further block production is needed.  if previous sections change, then this may need to be re-adjusted*)
      (let%bind (labeled_chains : (string * string list) list) =
         Malleable_error.List.map all_nodes ~f:(fun node ->
             let%map chain = Network.Node.must_get_best_chain ~logger node in
             (Node.id node, List.map ~f:(fun b -> b.state_hash) chain) )
       in
       let (chains : string list list) =
         List.map labeled_chains ~f:(fun (_, chain) -> chain)
       in
       print_chains labeled_chains ;
       Util.check_common_prefixes chains ~tolerance:1 ~logger )
end
