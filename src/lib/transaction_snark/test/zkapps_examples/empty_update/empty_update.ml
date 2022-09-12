open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Parties_segment = Transaction_snark.Parties_segment

let sk = Private_key.create ()

let pk = Public_key.of_private_key_exn sk

let pk_compressed = Public_key.compress pk

let account_id = Account_id.create pk_compressed Token_id.default

let tag, _, p_module, Pickles.Provers.[ prover ] =
  Zkapps_examples.compile () ~cache:Cache_dir.cache ~auxiliary_typ:Impl.Typ.unit
    ~branches:(module Nat.N1)
    ~max_proofs_verified:(module Nat.N0)
    ~name:"empty_update"
    ~constraint_constants:
      (Genesis_constants.Constraint_constants.to_snark_keys_header
         constraint_constants )
    ~choices:(fun ~self:_ -> [ Zkapps_empty_update.rule pk_compressed ])

module P = (val p_module)

let vk = Pickles.Side_loaded.Verification_key.of_compiled tag

let party, () = Async.Thread_safe.block_on_async_exn prover

let deploy_party_body : Party.Body.t =
  (* TODO: This is a pain. *)
  { Party.Body.dummy with
    public_key = pk_compressed
  ; update =
      { Party.Update.dummy with
        verification_key =
          Set
            { data = vk
            ; hash =
                (* TODO: This function should live in
                   [Side_loaded_verification_key].
                *)
                Zkapp_account.digest_vk vk
            }
      }
  ; preconditions =
      { Party.Preconditions.network = Zkapp_precondition.Protocol_state.accept
      ; account = Accept
      }
  ; caller = Token_id.default
  ; use_full_commitment = true
  }

let deploy_party : Party.t =
  (* TODO: This is a pain. *)
  { body = deploy_party_body; authorization = Signature Signature.dummy }

let other_parties =
  []
  |> Parties.Call_forest.cons_tree party
  |> Parties.Call_forest.cons deploy_party

let memo = Signed_command_memo.empty

let transaction_commitment : Parties.Transaction_commitment.t =
  (* TODO: This is a pain. *)
  let other_parties_hash = Parties.Call_forest.hash other_parties in
  Parties.Transaction_commitment.create ~other_parties_hash

let fee_payer =
  (* TODO: This is a pain. *)
  { Party.Fee_payer.body =
      { Party.Body.Fee_payer.dummy with
        public_key = pk_compressed
      ; fee = Currency.Fee.(nanomina 100)
      }
  ; authorization = Signature.dummy
  }

let full_commitment =
  (* TODO: This is a pain. *)
  Parties.Transaction_commitment.create_complete transaction_commitment
    ~memo_hash:(Signed_command_memo.hash memo)
    ~fee_payer_hash:(Parties.Digest.Party.create (Party.of_fee_payer fee_payer))

(* TODO: Make this better. *)
let sign_all ({ fee_payer; other_parties; memo } : Parties.t) : Parties.t =
  let fee_payer =
    match fee_payer with
    | { body = { public_key; _ }; _ }
      when Public_key.Compressed.equal public_key pk_compressed ->
        { fee_payer with
          authorization =
            Schnorr.Chunked.sign sk
              (Random_oracle.Input.Chunked.field full_commitment)
        }
    | fee_payer ->
        fee_payer
  in
  let other_parties =
    Parties.Call_forest.map other_parties ~f:(function
      | ({ body = { public_key; use_full_commitment; _ }
         ; authorization = Signature _
         } as party :
          Party.t )
        when Public_key.Compressed.equal public_key pk_compressed ->
          let commitment =
            if use_full_commitment then full_commitment
            else transaction_commitment
          in
          { party with
            authorization =
              Control.Signature
                (Schnorr.Chunked.sign sk
                   (Random_oracle.Input.Chunked.field commitment) )
          }
      | party ->
          party )
  in
  { fee_payer; other_parties; memo }

let parties : Parties.t =
  sign_all
    { fee_payer = { body = fee_payer.body; authorization = Signature.dummy }
    ; other_parties
    ; memo
    }

let () =
  Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
      let (_ : _) =
        Ledger.get_or_create_account ledger account_id
          (Account.create account_id
             Currency.Balance.(
               Option.value_exn (add_amount zero (Currency.Amount.nanomina 500))) )
      in
      ignore (apply_parties ledger [ parties ] : Sparse_ledger.t) )
