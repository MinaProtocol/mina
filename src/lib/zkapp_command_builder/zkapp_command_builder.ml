(* zkapp_command_builder.ml -- combinators to build Zkapp_command.t for tests *)

open Core_kernel
open Mina_base

let mk_forest ps :
    (Account_update.Body.Simple.t, unit, unit) Zkapp_command.Call_forest.t =
  List.map ps ~f:(fun p -> { With_stack_hash.elt = p; stack_hash = () })

let mk_node account_update calls : _ Zkapp_command.Call_forest.Tree.t =
  { account_update; account_update_digest = (); calls = mk_forest calls }

let mk_account_update_body ?preconditions ?(increment_nonce = false)
    ?(update = Account_update.Update.noop) authorization_kind may_use_token kp
    token_id balance_change : Account_update.Body.Simple.t =
  let open Signature_lib in
  let preconditions =
    Option.value preconditions
      ~default:
        Account_update.Preconditions.
          { network = Zkapp_precondition.Protocol_state.accept
          ; account = Zkapp_precondition.Account.accept
          ; valid_while = Ignore
          }
  in
  { update
  ; public_key = Public_key.compress kp.Keypair.public_key
  ; token_id
  ; balance_change =
      Currency.Amount.Signed.create
        ~magnitude:
          (Currency.Amount.of_nanomina_int_exn (Int.abs balance_change))
        ~sgn:(if Int.is_negative balance_change then Sgn.Neg else Pos)
  ; increment_nonce
  ; events = []
  ; actions = []
  ; call_data = Pickles.Impls.Step.Field.Constant.zero
  ; call_depth = 0
  ; preconditions
  ; use_full_commitment = true
  ; implicit_account_creation_fee = false
  ; may_use_token
  ; authorization_kind
  }

let mk_zkapp_command ?memo ~fee ~fee_payer_pk ~fee_payer_nonce account_updates :
    Zkapp_command.t =
  let fee_payer : Account_update.Fee_payer.t =
    { body =
        { public_key = fee_payer_pk
        ; fee = Currency.Fee.of_nanomina_int_exn fee
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
  ; account_updates =
      account_updates
      |> Zkapp_command.Call_forest.map
           ~f:(fun (p : Account_update.Body.Simple.t) : Account_update.t ->
             let authorization =
               match p.authorization_kind with
               | None_given ->
                   Control.None_given
               | Proof _ ->
                   Control.Proof Mina_base.Proof.blockchain_dummy
               | Signature ->
                   Control.Signature Signature.dummy
             in
             { body = Account_update.Body.of_simple p; authorization } )
      |> Zkapp_command.Call_forest.accumulate_hashes_predicated
  }

(* replace dummy signatures, proofs with valid ones for fee payer, other zkapp_command
   [keymap] maps compressed public keys to private keys
*)
let replace_authorizations ?prover ~keymap (zkapp_command : Zkapp_command.t) :
    Zkapp_command.t Async_kernel.Deferred.t =
  let txn_commitment, full_txn_commitment =
    Zkapp_command.get_transaction_commitments zkapp_command
  in
  let sign_for_account_update ~use_full_commitment sk =
    let commitment =
      if use_full_commitment then full_txn_commitment else txn_commitment
    in
    Signature_lib.Schnorr.Chunked.sign sk
      (Random_oracle.Input.Chunked.field commitment)
  in
  let fee_payer_sk =
    Signature_lib.Public_key.Compressed.Map.find_exn keymap
      zkapp_command.fee_payer.body.public_key
  in
  let fee_payer_signature =
    sign_for_account_update ~use_full_commitment:true fee_payer_sk
  in
  let fee_payer_with_valid_signature =
    { zkapp_command.fee_payer with authorization = fee_payer_signature }
  in
  let open Async_kernel.Deferred.Let_syntax in
  let%map account_updates_with_valid_authorizations =
    Zkapp_command.Call_forest.deferred_mapi zkapp_command.account_updates
      ~f:(fun _ndx ({ body; authorization } : Account_update.t) tree ->
        let%map valid_authorization =
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
              let signature = sign_for_account_update ~use_full_commitment sk in
              return (Control.Signature signature)
          | Proof _proof -> (
              match prover with
              | None ->
                  return authorization
              | Some prover ->
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
              return authorization
        in
        { Account_update.body; authorization = valid_authorization } )
  in
  { zkapp_command with
    fee_payer = fee_payer_with_valid_signature
  ; account_updates = account_updates_with_valid_authorizations
  }
