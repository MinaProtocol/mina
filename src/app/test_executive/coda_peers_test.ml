open Async
open Core
open Integration_test_lib

module Make (Engine : Engine_intf) = struct
  open Engine

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type log_engine = Log_engine.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    { default with
      block_producers= [{balance= "1000"}; {balance= "1000"}; {balance= "1000"}]
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
    let get_peer_id_partial = Node.get_peer_id ~logger in
    let expected_peers = List.map peer_list ~f:get_peer_id_partial in
    let test_compare_func n =
      let visible_peers_of_n =
        []
        (* TODO, write a graphql query that asks n what it thinks its peers are *)
      in
      let expected_peers_of_n =
        []
        (* TODO, expected_peers minus n's own peer id *)
      in
      List.iter visibile_peers_of_n ~f:(fun p ->
          assert (List.exists p expected_peers_of_n) )
      (* loop through visibile_peers_of_n and make sure everything in that list is also in expected_peers_of_n *)
    in
    Malleable_errors.List.iter peer_list ~f:test_compare_func
end
