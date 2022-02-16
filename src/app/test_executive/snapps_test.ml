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
           Parties.t plus another for the payment receiver
        *)
    ; block_producers =
        List.init 5 ~f:(fun _ -> { balance = "2000000000"; timing = Untimed })
    ; num_snark_workers =
        0
        (* We use a small scan state to make sure we can get some ledger proofs emitted quickly *)
    ; transaction_capacity = Some (Log_2 2)
    }

  (* An event which fires when [n] ledger proofs have been emitted *)
  let ledger_proofs_emitted ~num_proofs =
    Wait_condition.network_state ~description:"snarked ledger emitted"
      ~f:(fun network_state ->
        network_state.snarked_ledgers_generated > num_proofs)
    |> Wait_condition.with_timeouts ~soft_timeout:(Slots 10)
         ~hard_timeout:(Slots 10)

  (* Call [f] [n] times in sequence *)
  let repeat ~n ~f =
    let open Malleable_error.Let_syntax in
    let rec go i =
      if i = 0 then return ()
      else
        let%bind () = f () in
        go (i - 1)
    in
    go n

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let%bind () =
      Malleable_error.List.iter block_producer_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let node = List.hd_exn block_producer_nodes in
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
        Mina_base.Parties.Call_forest.With_hashes.other_parties_hash
          parties_valid_fee_payer_signature.other_parties
      in
      let protocol_state_predicate_hash =
        Mina_base.Snapp_predicate.Protocol_state.digest
          parties_valid_fee_payer_signature.fee_payer.data.body.protocol_state
      in
      let memo_hash =
        Mina_base.Signed_command_memo.hash
          parties_valid_fee_payer_signature.memo
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
        { parties_valid_fee_payer_signature with
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
    let parties_no_fee_payer_update =
      { parties_valid_pks with
        fee_payer =
          { parties_valid_pks.fee_payer with
            data =
              { parties_valid_pks.fee_payer.data with
                body =
                  { parties_valid_pks.fee_payer.data.body with
                    update = Mina_base.Party.Update.noop
                  ; sequence_events = []
                  }
              }
          }
      }
    in
    let%bind parties_valid =
      mk_parties_with_signatures ~fee_payer_nonce:Mina_base.Account.Nonce.zero
        parties_no_fee_payer_update
    in
    let sender_pub_key = fee_payer_pk in
    (* choose payment receiver that is not in the snapp other parties
       because there's a check that user commands can't involve snapp accounts
    *)
    let receiver =
      List.nth_exn block_producer_nodes
        (List.length parties_valid.other_parties + 1)
    in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver in
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
            Network.Node.must_send_payment ~logger node ~sender_pub_key
              ~receiver_pub_key ~amount ~fee
          in
          [%log info] "Sent payment" )
    in
    let timeout = Network_time_span.Slots 2 in
    let%bind () =
      section "Wait for snapp, payment inclusion in transition frontier"
        (let%bind () =
           wait_for t
           @@ Wait_condition.with_timeouts ~soft_timeout:timeout
                ~hard_timeout:timeout
           @@ Wait_condition.snapp_to_be_included_in_frontier
                ~parties:parties_valid
         in
         [%log info] "Snapps transaction included in transition frontier" ;
         let%map () =
           wait_for t
           @@ Wait_condition.with_timeouts ~soft_timeout:timeout
                ~hard_timeout:timeout
           @@ Wait_condition.payment_to_be_included_in_frontier ~sender_pub_key
                ~receiver_pub_key ~amount
         in
         [%log info] "Payment included in transition frontier")
    in
    let%bind () =
      section "Send payments and wait for proof to be emitted"
        (let%bind () =
           repeat ~n:20 ~f:(fun () ->
               Network.Node.must_send_payment ~logger node ~sender_pub_key
                 ~receiver_pub_key ~amount:Currency.Amount.one
                 ~fee:Currency.Fee.one)
         in
         wait_for t (ledger_proofs_emitted ~num_proofs:2))
    in
    let%bind () =
      section "send a snapp with bad fee payer signature"
        (* update nonce, signatures

           we've sent a snapp and payment with the same account, so new nonce is 2

           if we don't provide a valid nonce, the snapps would fail with Invalid_nonce
           instead of the desired Invalid_signature
        *)
        (let%bind parties_next_nonce =
           mk_parties_with_signatures
             ~fee_payer_nonce:(Mina_base.Account.Nonce.of_int 2)
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
