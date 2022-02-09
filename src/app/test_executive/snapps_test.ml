open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    let open Test_config.Block_producer in
    { default with
      requires_graphql =
        true
        (* must have at least as many block producers as party's in any
           Parties.t, because we need that many keypairs
        *)
    ; block_producers =
        [ { balance = "3000000000"; timing = Untimed }
        ; { balance = "3000000000"; timing = Untimed }
        ; { balance = "3000000000"; timing = Untimed }
        ; { balance = "3000000000"; timing = Untimed }
        ; { balance = "3000000000"; timing = Untimed }
        ; { balance = "3000000000"; timing = Untimed }
        ]
    ; num_snark_workers = 0
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let%bind () =
      Malleable_error.List.iter block_producer_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let node = List.nth_exn block_producer_nodes 0 in
    let[@warning "-8"] (Parties parties0 : Mina_base.User_command.t), _, _, _ =
      Quickcheck.random_value
        (Mina_base.User_command_generators.parties_with_ledger ())
    in
    let mk_parties_with_signatures ~fee_payer_nonce
        (parties : Mina_base.Parties.t) =
      let%bind fee_payer_sk = Util.priv_key_of_node node in
      let parties_with_updated_nonce =
        (* TODO: someday, use a lens *)
        { parties with
          fee_payer =
            { parties.fee_payer with
              data = { parties.fee_payer.data with predicate = fee_payer_nonce }
            }
        }
      in
      let fee_payer_hash =
        Mina_base.Party.Predicated.of_fee_payer
          parties_with_updated_nonce.fee_payer.data
        |> Mina_base.Party.Predicated.digest
      in
      let fee_payer_signature =
        Signature_lib.Schnorr.Chunked.sign fee_payer_sk
          (Random_oracle.Input.Chunked.field
             ( Mina_base.Parties.commitment parties_with_updated_nonce
             |> Mina_base.Parties.Transaction_commitment.with_fee_payer
                  ~fee_payer_hash ))
      in
      (* substitute valid signature for fee payer *)
      let parties_valid_fee_payer_signature =
        { parties_with_updated_nonce with
          fee_payer =
            { parties_with_updated_nonce.fee_payer with
              authorization = fee_payer_signature
            }
        }
      in
      let other_parties_hash =
        Mina_base.Parties.Party_or_stack.With_hashes.other_parties_hash
          parties_valid_fee_payer_signature.other_parties
      in
      let parties_with_other_parties_nonces =
        { parties_valid_fee_payer_signature with
          other_parties = parties_valid_fee_payer_signature.other_parties
        }
      in
      let protocol_state_predicate_hash =
        Mina_base.Snapp_predicate.Protocol_state.digest
          parties_with_other_parties_nonces.fee_payer.data.body.protocol_state
      in
      let memo_hash =
        Mina_base.Signed_command_memo.hash
          parties_with_other_parties_nonces.memo
      in
      let tx_commitment =
        Mina_base.Parties.Transaction_commitment.create ~other_parties_hash
          ~protocol_state_predicate_hash ~memo_hash
      in
      let full_tx_commitment =
        Mina_base.Parties.Transaction_commitment.with_fee_payer tx_commitment
          ~fee_payer_hash
      in
      let sign_for_other_party ~use_full_commitment sk =
        let commitment =
          if use_full_commitment then full_tx_commitment else tx_commitment
        in
        Signature_lib.Schnorr.Chunked.sign sk
          (Random_oracle.Input.Chunked.field commitment)
      in
      (* we also need to update the other parties signatures, if there's a full commitment,
         which relies on the fee payer hash
      *)
      let%bind other_parties_with_valid_signatures =
        Malleable_error.List.mapi
          parties_valid_fee_payer_signature.other_parties
          ~f:(fun ndx { data; authorization } ->
            (* 0th node has keypair for fee payer, so start at 1 *)
            let node = List.nth_exn block_producer_nodes (ndx + 1) in
            let%map sk = Util.priv_key_of_node node in
            let authorization_with_valid_signature =
              match authorization with
              | Mina_base.Control.Signature _dummy ->
                  let use_full_commitment = data.body.use_full_commitment in
                  let signature =
                    sign_for_other_party ~use_full_commitment sk
                  in
                  Mina_base.Control.Signature signature
              | Proof _ | None_given ->
                  authorization
            in
            { Mina_base.Party.data
            ; authorization = authorization_with_valid_signature
            })
      in
      return
        { parties_with_other_parties_nonces with
          other_parties = other_parties_with_valid_signatures
        }
    in
    (* the generated parties0 has a fee payer, other parties with public
       keys not found in the integration test ledger, so we replace those keys
    *)
    let%bind fee_payer_pk = Util.pub_key_of_node node in
    let%bind other_parties_with_valid_keys =
      Malleable_error.List.mapi parties0.other_parties
        ~f:(fun ndx { data; authorization } ->
          (* 0th node has keypair for fee payer, so start at 1 *)
          let node = List.nth_exn block_producer_nodes (ndx + 1) in
          let%map pk = Util.pub_key_of_node node in
          let data = { data with body = { data.body with public_key = pk } } in
          { Mina_base.Party.data; authorization })
    in
    let parties_valid_pks =
      { parties0 with
        fee_payer =
          { parties0.fee_payer with
            data =
              { parties0.fee_payer.data with
                body =
                  { parties0.fee_payer.data.body with
                    public_key = fee_payer_pk
                  }
              }
          }
      ; other_parties = other_parties_with_valid_keys
      }
    in
    let%bind parties_valid =
      mk_parties_with_signatures ~fee_payer_nonce:Unsigned.UInt32.zero
        parties_valid_pks
    in
    (* choose payment sender, receiver that are not in the snapp other parties
       because there's a check that user commands can't involve snapp accounts
       TODO: that check will be removed; change sender to snapp fee payer
    *)
    let sender =
      List.nth_exn block_producer_nodes
        (List.length parties_valid.other_parties + 1)
    in
    let receiver =
      List.nth_exn block_producer_nodes
        (List.length parties_valid.other_parties + 2)
    in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver in
    let%bind sender_pub_key = Util.pub_key_of_node sender in
    (* other payment info *)
    let amount = Currency.Amount.of_int 2_000_000_000 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let%bind () =
      section "send a valid snapp"
        ( [%log info] "Sending valid snapp" ;
          match%bind.Deferred
            Network.Node.send_snapp ~logger node ~parties:parties_valid
          with
          | Ok _snapp_id ->
              [%log info] "Snapps transaction sent" ;
              Malleable_error.return ()
          | Error err ->
              let err_str = Error.to_string_mach err in
              [%log error] "Error sending snapp"
                ~metadata:[ ("error", `String err_str) ] ;
              Malleable_error.soft_error_format ~value:()
                "Error sending snapp: %s" err_str )
    in
    let%bind () =
      section "send payment"
        ( [%log info] "Sending payment" ;
          let%map () =
            Network.Node.must_send_payment ~logger sender ~sender_pub_key
              ~receiver_pub_key ~amount ~fee
          in
          [%log info] "Sent payment" )
    in
    let%bind () =
      section "Wait for snapp, payment inclusion in transition frontier"
        (let%bind () =
           wait_for t
           @@ Wait_condition.snapp_to_be_included_in_frontier
                ~parties:parties_valid
         in
         [%log info] "Snapps transaction included in transition frontier" ;
         let%map () =
           wait_for t
           @@ Wait_condition.payment_to_be_included_in_frontier ~sender_pub_key
                ~receiver_pub_key ~amount
         in
         [%log info] "Payment included in transition frontier")
    in
    let%bind () =
      section "send a snapp with bad fee payer signature"
        (* update nonce, signatures

           we've sent a snapp and a payment with the same account, so new nonce is 2

           if we don't provide a valid nonce, the snapps would fail with Invalid_nonce
           instead of the desired Invalid_signature
        *)
        (let%bind parties_next_nonce =
           mk_parties_with_signatures
             ~fee_payer_nonce:Unsigned.UInt32.(succ one)
             parties_valid_pks
         in
         let parties_bad_signature =
           { parties_next_nonce with
             fee_payer =
               { parties_next_nonce.fee_payer with
                 authorization = Mina_base.Signature.dummy
               }
           }
         in
         [%log info] "Sending snapp with invalid signature" ;
         match%bind.Deferred
           Network.Node.send_snapp ~logger node ~parties:parties_bad_signature
         with
         | Ok _snapp_id ->
             [%log error]
               "Snapps transaction succeeded, expected failure due to invalid \
                signature" ;
             Malleable_error.soft_error_format ~value:()
               "Snapps transaction succeeded despite invalid signature"
         | Error err ->
             let err_str = Error.to_string_mach err in
             if String.is_substring ~substring:"Invalid_signature" err_str then (
               [%log info] "Snapps failed as expected with invalid signature" ;
               Malleable_error.return () )
             else (
               [%log error]
                 "Error sending snapp, for a reason other than the expected \
                  invalid signature"
                 ~metadata:[ ("error", `String err_str) ] ;
               Malleable_error.soft_error_format ~value:()
                 "Snapp failed in unexpected way: %s" err_str ))
    in
    return ()
end
