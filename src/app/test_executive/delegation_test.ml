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
      requires_graphql = true
    ; genesis_ledger =
        [ { account_name = "node-a-key"; balance = "1000"; timing = Untimed }
        ; { account_name = "node-b-key"; balance = "1000"; timing = Untimed }
        ]
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ]
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    (* fee for user commands *)
    let fee = Currency.Fee.of_int 10_000_000 in
    let all_mina_nodes = Network.all_mina_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (Core.String.Map.data all_mina_nodes) )
    in
    let node_a =
      Core.String.Map.find_exn (Network.block_producers network) "node-a"
    in
    let node_b =
      Core.String.Map.find_exn (Network.block_producers network) "node-b"
    in
    let%bind () =
      section "delegate all mina currency from node_b to node_a"
        (let delegation_receiver = node_a in
         let%bind delegation_receiver_pub_key =
           pub_key_of_node delegation_receiver
         in
         let delegation_sender = node_b in
         let%bind delegation_sender_pub_key =
           pub_key_of_node delegation_sender
         in
         let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_delegation ~logger
             (Network.Node.get_ingress_uri delegation_sender)
             ~sender_pub_key:delegation_sender_pub_key
             ~receiver_pub_key:delegation_receiver_pub_key ~fee
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:`Any_node ) )
    in
    Malleable_error.return ()
end
