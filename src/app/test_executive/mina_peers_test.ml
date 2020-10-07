open Core
open Integration_test_lib
open Currency

module Make (Engine : Engine_intf) = struct
  open Engine

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type log_engine = Log_engine.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    let timing : Coda_base.Account_timing.t =
      Timed
        { initial_minimum_balance= Balance.of_int 1000
        ; cliff_time= Coda_numbers.Global_slot.of_int 4
        ; vesting_period= Coda_numbers.Global_slot.of_int 2
        ; vesting_increment= Amount.of_int 50_000_000_000 }
    in
    { default with
      block_producers=
        [ {balance= "1000"; timing}
        ; {balance= "1000"; timing}
        ; {balance= "1000"; timing} ]
    ; num_snark_workers= 0 }

  let run network log_engine =
    let open Network in
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let wait_for_init_partial node =
      Log_engine.wait_for_init node log_engine
    in
    let%bind () =
      Malleable_error.List.iter network.block_producers
        ~f:wait_for_init_partial
    in
    let peer_list = network.block_producers in
    (* [%log info] "peers_list"
      ~metadata:
      [("namespace", `String t.namespace); ("pod_id", `String t.pod_id)] ; *)
    let get_peer_id_partial = Node.get_peer_id ~logger in
    let%bind query_result =
      Malleable_error.List.map peer_list ~f:get_peer_id_partial
    in
    (* query_result is of type (string * string sexp_list) sexp_list *)
    (* each element represents the data of a single node relevant to this test. ( peer_id of node * [list of peer_ids of node's peers] ) *)
    let expected_peers, _ = List.unzip query_result in
    let test_compare_func (node_peer_id, visible_peers_of_node) =
      let expected_peers_of_node : string list =
        List.filter
          ~f:(fun p -> if String.equal p node_peer_id then false else true)
          expected_peers
        (* expected_peers_of_node is just expected_peers but with the peer_id of the given node removed from the list *)
      in
      List.iter visible_peers_of_node ~f:(fun p ->
          assert (
            List.exists expected_peers_of_node ~f:(fun x ->
                if String.equal x p then true else false ) ) )
      (* loop through visible_peers_of_node and make sure everything in that list is also in expected_peers_of_node *)
    in
    return (List.iter query_result ~f:test_compare_func)
end
