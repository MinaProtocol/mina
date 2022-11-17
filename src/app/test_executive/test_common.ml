(* test_common.ml -- code common to tests *)

(* open Core_kernel *)
open Integration_test_lib
open Core
open Async

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  (* open Engine *)
  (* open Dsl *)

  let pub_key_of_node node =
    let open Signature_lib in
    match Engine.Network.Node.network_keypair node with
    | Some nk ->
        Malleable_error.return (nk.keypair.public_key |> Public_key.compress)
    | None ->
        Malleable_error.hard_error_format
          "Node '%s' did not have a network keypair, if node is a block \
           producer this should not happen"
          (Engine.Network.Node.id node)

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

  module X = struct
    include String

    type display = string [@@deriving yojson]

    let display = Fn.id

    let name = Fn.id
  end

  module G = Visualization.Make_ocamlgraph (X)

  let graph_of_adjacency_list (adj : (string * string list) list) =
    List.fold adj ~init:G.empty ~f:(fun acc (x, xs) ->
        let acc = G.add_vertex acc x in
        List.fold xs ~init:acc ~f:(fun acc y ->
            let acc = G.add_vertex acc y in
            G.add_edge acc x y ) )

  let fetch_connectivity_data ~logger nodes =
    let open Malleable_error.Let_syntax in
    Malleable_error.List.map nodes ~f:(fun node ->
        let%map response = Engine.Network.Node.must_get_peer_id ~logger node in
        (node, response) )

  let assert_peers_completely_connected nodes_and_responses =
    (* this check checks if every single peer in the network is connected to every other peer, in graph theory this network would be a complete graph.  this property will only hold true on small networks *)
    let check_peer_connected_to_all_others ~nodes_by_peer_id ~peer_id
        ~connected_peers =
      let get_node_id p =
        p |> String.Map.find_exn nodes_by_peer_id |> Engine.Network.Node.id
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
            ~error_type:`Hard ~error )
    in

    let nodes_by_peer_id =
      nodes_and_responses
      |> List.map ~f:(fun (node, (peer_id, _)) -> (peer_id, node))
      |> String.Map.of_alist_exn
    in
    Malleable_error.List.iter nodes_and_responses
      ~f:(fun (_, (peer_id, connected_peers)) ->
        check_peer_connected_to_all_others ~nodes_by_peer_id ~peer_id
          ~connected_peers )

  let assert_peers_cant_be_partitioned ~max_disconnections nodes_and_responses =
    (* this check checks that the network does NOT become partitioned into isolated subgraphs, even if n nodes are hypothetically removed from the network.*)
    let _, responses = List.unzip nodes_and_responses in
    let open Graph_algorithms in
    let () =
      Out_channel.with_file "/tmp/network-graph.dot" ~f:(fun c ->
          G.output_graph c (graph_of_adjacency_list responses) )
    in
    (* Check that the network cannot be disconnected by removing up to max_disconnections number of nodes. *)
    match
      Nat.take
        (Graph_algorithms.connectivity (module String) responses)
        max_disconnections
    with
    | `Failed_after n ->
        Malleable_error.hard_error_format
          "The network could be disconnected by removing %d node(s)" n
    | `Ok ->
        Malleable_error.return ()

  (* [logs] is a string containing the entire replayer output *)
  let check_replayer_logs ~logger logs =
    let log_level_substring level = sprintf {|"level":"%s"|} level in
    let error_log_substring = log_level_substring "Error" in
    let fatal_log_substring = log_level_substring "Fatal" in
    let info_log_substring = log_level_substring "Info" in
    let split_logs = String.split logs ~on:'\n' in
    let error_logs =
      split_logs
      |> List.filter ~f:(fun log ->
             String.is_substring log ~substring:error_log_substring
             || String.is_substring log ~substring:fatal_log_substring )
    in
    let info_logs =
      split_logs
      |> List.filter ~f:(fun log ->
             String.is_substring log ~substring:info_log_substring )
    in
    let num_info_logs = List.length info_logs in
    if num_info_logs < 25 then
      Malleable_error.hard_error_string
        (sprintf "Replayer output contains suspiciously few (%d) Info logs"
           num_info_logs )
    else if List.is_empty error_logs then (
      [%log info] "The replayer encountered no errors" ;
      Malleable_error.return () )
    else
      let error = String.concat error_logs ~sep:"\n  " in
      Malleable_error.hard_error_string ("Replayer errors:\n  " ^ error)
end
