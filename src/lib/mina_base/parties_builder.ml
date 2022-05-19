(* parties_builder.ml -- combinators to build Parties.t for tests *)

open Base

let mk_forest ps : (Party.Body.Wire.t, unit, unit) Parties.Call_forest.t =
  List.map ps ~f:(fun p -> { With_stack_hash.elt = p; stack_hash = () })

let mk_node party calls =
  { Parties.Call_forest.Tree.party; party_digest = (); calls = mk_forest calls }

let mk_party_body caller kp token_id balance_change : Party.Body.Wire.t =
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
  ; protocol_state_precondition = Zkapp_precondition.Protocol_state.accept
  ; use_full_commitment = true
  ; account_precondition = Accept
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
           ~f:(fun (p : Party.Body.Wire.t) : Party.Wire.t ->
             { body = p; authorization = Signature Signature.dummy } )
      |> Parties.Call_forest.add_callers'
      |> Parties.Call_forest.accumulate_hashes_predicated
  }
