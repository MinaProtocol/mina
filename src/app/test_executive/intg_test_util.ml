open Core
open Integration_test_lib
open Async
open Dsl
open Network
open Engine

let check_common_prefixes ~tolerance ~logger chains =
  assert (List.length chains > 1) ;
  let hashset_chains = List.map chains ~f:(Hash_set.of_list (module String)) in
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
        "Chains have common prefix of %d blocks, longest absolute chain is %d \
         blocks.  the difference is %d blocks, which is greater than allowed \
         tolerance of %d blocks"
        common_prefixes_length longest_chain_length length_difference tolerance
    in
    [%log error] "%s" error_str ;
    Malleable_error.soft_error ~value:() (Error.of_string error_str)

type network = Network.t

type node = Network.Node.t

(* this function not exported *)
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
