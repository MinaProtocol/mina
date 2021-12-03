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

  let check_common_prefixes ~tolerance ~logger chains =
    assert (List.length chains > 1) ;
    let hashset_chains =
      List.map chains ~f:(Hash_set.of_list (module String))
    in
    let longest_chain_length =
      chains |> List.map ~f:List.length
      |> List.max_elt ~compare:Int.compare
      |> Option.value_exn
    in
    let common_prefixes =
      List.reduce hashset_chains ~f:Hash_set.inter |> Option.value_exn
    in
    let common_prefixes_length = Hash_set.length common_prefixes in
    let length_difference = longest_chain_length - common_prefixes_length in
    if length_difference = 0 || length_difference <= tolerance then
      Malleable_error.return ()
    else
      let error_str =
        sprintf
          "Chains have common prefix of %d blocks, longest absolute chain is \
           %d blocks.  the difference is %d blocks, which is greater than \
           allowed tolerance of %d blocks"
          common_prefixes_length longest_chain_length length_difference
          tolerance
      in
      [%log error] "%s" error_str ;
      Malleable_error.soft_error ~value:() (Error.of_string error_str)

  let check_peer_connectivity ~nodes_by_peer_id ~peer_id ~connected_peers =
    let get_node_id p =
      p |> String.Map.find_exn nodes_by_peer_id |> Network.Node.id
    in
    let expected_peers =
      nodes_by_peer_id |> String.Map.keys
      |> List.filter ~f:(fun p -> not (String.equal p peer_id))
    in
    Malleable_error.List.iter expected_peers ~f:(fun p ->
        let error =
          Printf.sprintf "node %s (id=%s) is not connected to node %s (id=%s)"
            (get_node_id peer_id) peer_id (get_node_id p) p
          |> Error.of_string
        in
        Malleable_error.ok_if_true
          (List.mem connected_peers p ~equal:String.equal)
          ~error_type:`Hard ~error)

  let check_peers ~logger nodes =
    let open Malleable_error.Let_syntax in
    let%bind nodes_and_responses =
      Malleable_error.List.map nodes ~f:(fun node ->
          let%map response = Network.Node.must_get_peer_id ~logger node in
          (node, response))
    in
    let nodes_by_peer_id =
      nodes_and_responses
      |> List.map ~f:(fun (node, (peer_id, _)) -> (peer_id, node))
      |> String.Map.of_alist_exn
    in
    Malleable_error.List.iter nodes_and_responses
      ~f:(fun (_, (peer_id, connected_peers)) ->
        check_peer_connectivity ~nodes_by_peer_id ~peer_id ~connected_peers)

  let run network t =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    (* TEMP: until we fix the seed graphql port, we will only check peers for block producers *)
    (* let all_nodes = Network.all_nodes network in *)
    let all_nodes = Network.block_producers network in
    let[@warning "-8"] [ node_a; node_b; node_c ] =
      Network.block_producers network
    in
    (* TODO: let%bind () = wait_for t (Wait_condition.nodes_to_initialize [node_a; node_b; node_c]) in *)
    let%bind () =
      Malleable_error.List.iter [ node_a; node_b; node_c ]
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let%bind () =
      section "network is fully connected upon initialization"
        (check_peers ~logger all_nodes)
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
                ~hard_timeout:
                  (Network_time_span.Literal
                     (Time.Span.of_ms (15. *. 60. *. 1000.))) ))
    in
    let print_chains (labeled_chain_list : (string * string list) list) =
      List.iter labeled_chain_list ~f:(fun labeled_chain ->
          let label, chain = labeled_chain in
          let chain_str = String.concat ~sep:"\n" chain in
          [%log info] "\nchain of %s:\n %s" label chain_str)
    in
    let%bind () =
      section "common prefix of all nodes is no farther back than 1 block"
        (* the common prefix test relies on at least 4 blocks having been produced.  previous sections altogether have already produced 4, so no further block production is needed.  if previous sections change, then this may need to be re-adjusted*)
        (let%bind (labeled_chains : (string * string list) list) =
           Malleable_error.List.map all_nodes ~f:(fun node ->
               let%map chain = Network.Node.must_get_best_chain ~logger node in
               (Node.id node, chain))
         in
         let (chains : string list list) =
           List.map labeled_chains ~f:(fun (_, chain) -> chain)
         in
         print_chains labeled_chains ;
         check_common_prefixes chains ~tolerance:1 ~logger)
    in
    section "network is fully connected after one node was restarted"
      (let%bind () = Malleable_error.lift (after (Time.Span.of_sec 240.0)) in
       check_peers ~logger all_nodes)
end
