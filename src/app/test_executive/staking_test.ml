open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config ~(constants : Test_config.constants) =
    let open Test_config in
    { (default ~constants) with
      requires_graphql = true
    ; genesis_ledger =
        (let open Test_account in
        [ create ~account_name:"node-a-key" ~balance:"1000" ()
        ; create ~account_name:"node-b-key" ~balance:"1000" ()
        ])
    ; block_producers =
        [ { node_name = "node-a"; account_name = "node-a-key" }
        ; { node_name = "node-b"; account_name = "node-b-key" }
        ]
    }

  let run ~config:Test_config.{ signature_kind; _ } network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_mina_nodes = Network.all_mina_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (Core.String.Map.data all_mina_nodes) )
    in
    let node_a = Network.block_producer_exn network "node-a" in
    let node_b = Network.block_producer_exn network "node-b" in
    let%bind () =
      section "nodes are synced"
        (wait_for t (Wait_condition.nodes_to_synchronize [ node_a; node_b ]))
    in
    let receiver_kp = Signature_lib.Keypair.create () in
    let receiver_pk =
      Signature_lib.Public_key.compress receiver_kp.public_key
    in
    let receiver_account_id = Account_id.create receiver_pk Token_id.default in
    let%bind () =
      section "new account is created with empty delegate"
        (let%bind sender_pk = pub_key_of_node node_a in
         let amount = Currency.Amount.of_mina_string_exn "10" in
         let fee = Currency.Fee.of_mina_string_exn "1" in
         let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_online_payment
             ~logger
             (Network.Node.get_ingress_uri node_a)
             ~sender_pub_key:sender_pk ~receiver_pub_key:receiver_pk ~amount
             ~fee
         in
         let%bind () =
           wait_for t
             (Wait_condition.signed_command_to_be_included_in_frontier
                ~txn_hash:hash ~node_included_in:(`Node node_a) )
         in
         let%bind { delegate; _ } =
           Integration_test_lib.Graphql_requests.must_get_account_data ~logger
             (Network.Node.get_ingress_uri node_a)
             ~account_id:receiver_account_id
         in
         match delegate with
         | None ->
             Malleable_error.return ()
         | Some pk ->
             Malleable_error.hard_error_format
               "Expected newly created account to have empty delegate, but \
                delegate was %s"
               (Signature_lib.Public_key.Compressed.to_base58_check pk) )
    in
    section "delegation to unknown pk leaves delegate unchanged"
      (let unknown_pk =
         Signature_lib.(
           Public_key.compress (Keypair.create ()).public_key)
       in
       let fee = Currency.Fee.of_mina_string_exn "1" in
       let valid_until = Mina_numbers.Global_slot_since_genesis.max_value in
       let memo = "" in
       let%bind { nonce = sender_nonce; _ } =
         Integration_test_lib.Graphql_requests.must_get_account_data ~logger
           (Network.Node.get_ingress_uri node_a)
           ~account_id:receiver_account_id
       in
       let payload =
         let body =
           Signed_command_payload.Body.Stake_delegation
             (Set_delegate { new_delegate = unknown_pk })
         in
         let common =
           { Signed_command_payload.Common.Poly.fee
           ; fee_payer_pk = receiver_pk
           ; nonce = sender_nonce
           ; valid_until
           ; memo = Signed_command_memo.create_from_string_exn memo
           }
         in
         { Signed_command_payload.Poly.common; body }
       in
       let raw_signature =
         Signed_command.sign_payload ~signature_kind receiver_kp.private_key
           payload
         |> Signature.Raw.encode
       in
       let%bind { hash; _ } =
         Integration_test_lib.Graphql_requests
         .must_send_delegation_with_raw_sig ~logger
           (Network.Node.get_ingress_uri node_a)
           ~sender_pub_key:receiver_pk ~receiver_pub_key:unknown_pk ~fee
           ~nonce:sender_nonce ~memo ~valid_until ~raw_signature
       in
       let%bind () =
         wait_for t
           (Wait_condition.signed_command_to_be_included_in_frontier
              ~txn_hash:hash ~node_included_in:(`Node node_a) )
       in
       let%bind { delegate; _ } =
         Integration_test_lib.Graphql_requests.must_get_account_data ~logger
           (Network.Node.get_ingress_uri node_a)
           ~account_id:receiver_account_id
       in
       match delegate with
       | None ->
           Malleable_error.return ()
       | Some pk ->
           Malleable_error.hard_error_format
             "Expected delegate to remain empty after failed delegation, but \
              delegate was %s"
             (Signature_lib.Public_key.Compressed.to_base58_check pk) )
end
