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

let mk_parties_transaction ?memo ~fee ~fee_payer_pk ~fee_payer_nonce
    other_parties : Parties.t =
  let fee_payer : Party.Fee_payer.t =
    { body =
        { public_key = fee_payer_pk
        ; fee = Currency.Fee.of_int fee
        ; valid_until = None
        ; nonce = fee_payer_nonce
        }
    ; authorization = Signature.dummy
    }
  in
  let memo =
    Option.value_map memo ~default:Signed_command_memo.dummy
      ~f:Signed_command_memo.create_from_string_exn
  in
  { fee_payer
  ; memo
  ; other_parties =
      other_parties
      |> Parties.Call_forest.map
           ~f:(fun (p : Party.Body.Simple.t) : Party.Simple.t ->
             { body = p; authorization = Signature Signature.dummy } )
      |> Parties.Call_forest.add_callers_simple
      |> Parties.Call_forest.accumulate_hashes_predicated
  }

let get_transaction_commitments (parties : Parties.t) =
  let memo_hash = Signed_command_memo.hash parties.memo in
  let fee_payer_hash =
    Party.of_fee_payer parties.fee_payer |> Parties.Digest.Party.create
  in
  let other_parties_hash = Parties.other_parties_hash parties in
  let txn_commitment =
    Parties.Transaction_commitment.create ~other_parties_hash
  in
  let full_txn_commitment =
    Parties.Transaction_commitment.create_complete txn_commitment ~memo_hash
      ~fee_payer_hash
  in
  (txn_commitment, full_txn_commitment)

(* replace dummy signatures, proofs with valid ones for fee payer, other parties
   [keymap] maps compressed public keys to private keys
*)
let replace_authorizations ?prover ~keymap (parties : Parties.t) :
    Parties.t Async_kernel.Deferred.t =
  let txn_commitment, full_txn_commitment =
    get_transaction_commitments parties
  in
  let sign_for_party ~use_full_commitment sk =
    let commitment =
      if use_full_commitment then full_txn_commitment else txn_commitment
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
  let open Async_kernel.Deferred.Let_syntax in
  let%map other_parties_with_valid_signatures =
    Parties.Call_forest.deferred_mapi parties.other_parties
      ~f:(fun _ndx ({ body; authorization } : Party.t) tree ->
        let%map authorization_with_valid_signature =
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
              printf !"generating signature\n%!" ;
              let signature = sign_for_party ~use_full_commitment sk in
              return (Control.Signature signature)
          | Proof _ -> (
              match prover with
              | None ->
                  printf !"not generating proof\n%!" ;
                  return authorization
              | Some prover ->
                  printf !"generating proof\n%!" ;
                  let txn_stmt = Zkapp_statement.of_tree tree in
                  let handler
                      (Snarky_backendless.Request.With { request; respond }) =
                    match request with _ -> respond Unhandled
                  in
                  let%map (), (), proof =
                    prover ?handler:(Some handler) txn_stmt
                  in
                  Control.Proof proof )
          | None_given ->
              printf !"not generating anything\n%!" ;
              return authorization
        in
        { Party.body; authorization = authorization_with_valid_signature } )
  in
  { parties with
    fee_payer = fee_payer_with_valid_signature
  ; other_parties = other_parties_with_valid_signatures
  }
