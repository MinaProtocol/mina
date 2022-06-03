(* parties_builder.ml -- combinators to build Parties.t for tests *)

open Core_kernel
open Mina_base

let mk_forest ps : (Party.Body.Simple.t, unit, unit) Parties.Call_forest.t =
  List.map ps ~f:(fun p -> { With_stack_hash.elt = p; stack_hash = () })

let mk_node party calls =
  { Parties.Call_forest.Tree.party; party_digest = (); calls = mk_forest calls }

let mk_party_body caller kp token_id balance_change : Party.Body.Simple.t =
  let open Signature_lib in
  { update = Party.Update.noop
  ; public_key = Public_key.compress kp.Keypair.public_key
  ; token_id
  ; balance_change =
      Currency.Amount.Signed.create
        ~magnitude:(Currency.Amount.of_int (Int.abs balance_change))
        ~sgn:(if Int.is_negative balance_change then Sgn.Neg else Pos)
  ; increment_nonce = false
  ; events = []
  ; sequence_events = []
  ; call_data = Pickles.Impls.Step.Field.Constant.zero
  ; call_depth = 0
  ; preconditions =
      { network = Zkapp_precondition.Protocol_state.accept
      ; account = Party.Account_precondition.Accept
      }
  ; use_full_commitment = true
  ; caller
  }

let mk_parties_transaction ~fee ~fee_payer_pk ~fee_payer_nonce other_parties :
    Parties.t =
  let fee_payer : Party.Fee_payer.t =
    { body =
        { update = Party.Update.noop
        ; public_key = fee_payer_pk
        ; fee = Currency.Fee.of_int fee
        ; events = []
        ; sequence_events = []
        ; protocol_state_precondition = Zkapp_precondition.Protocol_state.accept
        ; nonce = fee_payer_nonce
        }
    ; authorization = Signature.dummy
    }
  in
  { fee_payer
  ; memo = Signed_command_memo.dummy
  ; other_parties =
      other_parties
      |> Parties.Call_forest.map
           ~f:(fun (p : Party.Body.Simple.t) : Party.Simple.t ->
             { body = p; authorization = Signature Signature.dummy } )
      |> Parties.Call_forest.add_callers_simple
      |> Parties.Call_forest.accumulate_hashes_predicated
  }

(* replace dummy signatures, proofs with valid ones for fee payer, other parties
   [keymap] maps compressed public keys to private keys
*)
let replace_authorizations ?prover ~keymap (parties : Parties.t) : Parties.t =
  let memo_hash = Signed_command_memo.hash parties.memo in
  let fee_payer_hash =
    Party.of_fee_payer parties.fee_payer |> Parties.Digest.Party.create
  in
  let other_parties_hash = Parties.other_parties_hash parties in
  let tx_commitment =
    Parties.Transaction_commitment.create ~other_parties_hash
  in
  let full_tx_commitment =
    Parties.Transaction_commitment.create_complete tx_commitment ~memo_hash
      ~fee_payer_hash
  in
  let sign_for_party ~use_full_commitment sk =
    let commitment =
      if use_full_commitment then full_tx_commitment else tx_commitment
    in
    Signature_lib.Schnorr.Chunked.sign sk
      (Random_oracle.Input.Chunked.field commitment)
  in
  let fee_payer_sk =
    Signature_lib.Public_key.Compressed.Map.find_exn keymap
      parties.fee_payer.body.public_key
  in
  let fee_payer_signature =
    sign_for_party ~use_full_commitment:true fee_payer_sk
  in
  let fee_payer_with_valid_signature =
    { parties.fee_payer with authorization = fee_payer_signature }
  in
  let other_parties_with_valid_signatures =
    Parties.Call_forest.mapi parties.other_parties
      ~f:(fun ndx ({ body; authorization } : Party.t) ->
        let authorization_with_valid_signature =
          match authorization with
          | Control.Signature _dummy ->
              let pk = body.public_key in
              let sk =
                match
                  Signature_lib.Public_key.Compressed.Map.find keymap pk
                with
                | Some sk ->
                    sk
                | None ->
                    failwithf
                      "Could not find private key for public key %s in keymap"
                      (Signature_lib.Public_key.Compressed.to_base58_check pk)
                      ()
              in
              let use_full_commitment = body.use_full_commitment in
              let signature = sign_for_party ~use_full_commitment sk in
              Control.Signature signature
          | Proof _ -> (
              match prover with
              | None ->
                  authorization
              | Some prover ->
                  let proof_party =
                    Parties.Call_forest.hash
                      (List.drop parties.other_parties ndx)
                  in
                  let txn_stmt : Zkapp_statement.t =
                    let commitment =
                      if body.use_full_commitment then full_tx_commitment
                      else tx_commitment
                    in
                    { transaction = commitment
                    ; at_party = (proof_party :> Snark_params.Tick.Field.t)
                    }
                  in
                  let handler
                      (Snarky_backendless.Request.With { request; respond }) =
                    match request with _ -> respond Unhandled
                  in
                  let proof =
                    Async_unix.Thread_safe.block_on_async_exn (fun () ->
                        prover ?handler:(Some handler)
                          ( []
                            : ( unit
                              , unit
                              , unit )
                              Pickles_types.Hlist.H3.T
                                (Pickles.Statement_with_proof)
                              .t )
                          txn_stmt )
                  in
                  Control.Proof proof )
          | None_given ->
              authorization
        in
        { Party.body; authorization = authorization_with_valid_signature } )
  in
  { parties with
    fee_payer = fee_payer_with_valid_signature
  ; other_parties = other_parties_with_valid_signatures
  }
