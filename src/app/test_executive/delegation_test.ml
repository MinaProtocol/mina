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
        ]
    ; num_snark_workers = 0
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    (* fee for user commands *)
    let fee = Currency.Fee.of_int 10_000_000 in
    let all_nodes = Network.all_nodes network in
    let%bind () = wait_for t (Wait_condition.nodes_to_initialize all_nodes) in
    let[@warning "-8"] [ node_a; node_b ] = Network.block_producers network in
    let%bind () =
      section "delegate all mina currency from node_b to node_a"
        (let amount = Currency.Amount.of_int 2_000_000_000 in
         (* let fee = Currency.Fee.of_int 10_000_000 in *)
         let delegation_receiver = node_a in
         let%bind delegation_receiver_pub_key =
           Util.pub_key_of_node delegation_receiver
         in
         let delegation_sender = node_b in
         let%bind delegation_sender_pub_key =
           Util.pub_key_of_node delegation_sender
         in
         let%bind { nonce; _ } =
           Network.Node.must_send_delegation ~logger delegation_sender
             ~sender_pub_key:delegation_sender_pub_key
             ~receiver_pub_key:delegation_receiver_pub_key ~amount ~fee
         in
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~sender_pub_key:delegation_sender_pub_key
              ~receiver_pub_key:delegation_receiver_pub_key ~amount ~nonce
              ~command_type:Send_delegation))
    in
    Malleable_error.return ()
end
