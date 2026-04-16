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
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize
           (Core.String.Map.data (Network.all_mina_nodes network)) )
    in
    let node_a = Network.block_producer_exn network "node-a" in
    let node_b = Network.block_producer_exn network "node-b" in
    let%bind () =
      section "nodes are synced"
        (wait_for t (Wait_condition.nodes_to_synchronize [ node_a; node_b ]))
    in
    let delegator_kp = Signature_lib.Keypair.create () in
    let delegator_pk =
      Signature_lib.Public_key.compress delegator_kp.public_key
    in
    let receiver_account_id = Account_id.create delegator_pk Token_id.default in
    let node_a_uri = Network.Node.get_ingress_uri node_a in
    let must_get_receiver () =
      Integration_test_lib.Graphql_requests.must_get_account_data ~logger
        node_a_uri ~account_id:receiver_account_id
    in
    (* Submit a stake-delegation signed locally by [receiver_kp], then wait
       for it to land in node_a's frontier with the expected success/failure
       status (via [signed_command_to_be_included_in_frontier_with_status],
       which reads status from the Breadcrumb_added event stream). Finally
       assert the on-ledger delegate equals [expected_delegate]. *)
    let delegate_and_assert ~section_name ~new_delegate ~expected_delegate
        ~has_failures =
      section section_name
        (let fee = Currency.Fee.of_mina_string_exn "1" in
         let valid_until = Mina_numbers.Global_slot_since_genesis.max_value in
         let memo = "" in
         let%bind { nonce = sender_nonce; _ } = must_get_receiver () in
         let payload =
           let body =
             Signed_command_payload.Body.Stake_delegation
               (Set_delegate { new_delegate })
           in
           let common =
             { Signed_command_payload.Common.Poly.fee
             ; fee_payer_pk = delegator_pk
             ; nonce = sender_nonce
             ; valid_until
             ; memo = Signed_command_memo.create_from_string_exn memo
             }
           in
           { Signed_command_payload.Poly.common; body }
         in
         let raw_signature =
           Signed_command.sign_payload ~signature_kind delegator_kp.private_key
             payload
           |> Signature.Raw.encode
         in
         let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests
           .must_send_delegation_with_raw_sig ~logger node_a_uri
             ~sender_pub_key:delegator_pk ~receiver_pub_key:new_delegate ~fee
             ~nonce:sender_nonce ~memo ~valid_until ~raw_signature
         in
         let%bind () =
           wait_for t
             (Wait_condition
              .signed_command_to_be_included_in_frontier_with_status
                ~txn_hash:hash ~has_failures )
         in
         let%bind { delegate; _ } = must_get_receiver () in
         let show_delegate = function
           | None ->
               "<none>"
           | Some pk ->
               Signature_lib.Public_key.Compressed.to_base58_check pk
         in
         if
           Option.equal Signature_lib.Public_key.Compressed.equal delegate
             expected_delegate
         then Malleable_error.return ()
         else
           Malleable_error.hard_error_format
             "Expected delegate to be %s but got %s"
             (show_delegate expected_delegate)
             (show_delegate delegate) )
    in
    let%bind () =
      section "new account is created with empty delegate"
        (let%bind sender_pk = pub_key_of_node node_a in
         let amount = Currency.Amount.of_mina_string_exn "10" in
         let fee = Currency.Fee.of_mina_string_exn "1" in
         let%bind { hash; _ } =
           Integration_test_lib.Graphql_requests.must_send_online_payment
             ~logger node_a_uri ~sender_pub_key:sender_pk
             ~receiver_pub_key:delegator_pk ~amount ~fee
         in
         let%bind () =
           wait_for t
             (Wait_condition.signed_command_to_be_included_in_frontier
                ~txn_hash:hash ~node_included_in:(`Node node_a) )
         in
         let%bind { delegate; _ } = must_get_receiver () in
         match delegate with
         | None ->
             Malleable_error.return ()
         | Some pk ->
             Malleable_error.hard_error_format
               "Expected newly created account to have empty delegate, but \
                delegate was %s"
               (Signature_lib.Public_key.Compressed.to_base58_check pk) )
    in
    let fresh_unknown_pk () =
      Signature_lib.(Public_key.compress (Keypair.create ()).public_key)
    in
    let%bind () =
      delegate_and_assert
        ~section_name:
          "delegation to unknown pk from unstaked account fails, leaves \
           delegate empty"
        ~new_delegate:(fresh_unknown_pk ()) ~expected_delegate:None
        ~has_failures:true
    in
    let%bind node_b_pk = pub_key_of_node node_b in
    let%bind () =
      delegate_and_assert
        ~section_name:"delegation to existing account updates the delegate"
        ~new_delegate:node_b_pk ~expected_delegate:(Some node_b_pk)
        ~has_failures:false
    in
    let%bind () =
      delegate_and_assert
        ~section_name:
          "delegation to unknown pk from staked account fails, leaves delegate \
           unchanged"
        ~new_delegate:(fresh_unknown_pk ()) ~expected_delegate:(Some node_b_pk)
        ~has_failures:true
    in
    delegate_and_assert
      ~section_name:"delegation to empty pk clears the delegate (unstake)"
      ~new_delegate:Signature_lib.Public_key.Compressed.empty
      ~expected_delegate:None ~has_failures:false
end
