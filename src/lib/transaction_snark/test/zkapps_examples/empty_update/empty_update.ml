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

module Statement = struct
  type t = unit

  let to_field_elements () = [||]
end

let tag, _, p_module, Pickles.Provers.[ prover ] =
  Pickles.compile ~cache:Cache_dir.cache
    (module Statement)
    (module Statement)
    ~public_input:(Output Zkapp_statement.typ)
    ~branches:(module Nat.N1)
    ~max_proofs_verified:(module Nat.N0)
    ~name:"empty_update"
    ~constraint_constants:
      (Genesis_constants.Constraint_constants.to_snark_keys_header
         constraint_constants )
    ~choices:(fun ~self:_ -> [ Zkapps_empty_update.rule pk_compressed ])

module P = (val p_module)

let vk = Pickles.Side_loaded.Verification_key.of_compiled tag

(* TODO: This should be entirely unnecessary. *)
let party_body = Zkapps_empty_update.generate_party pk_compressed

let _stmt, party_proof = Async.Thread_safe.block_on_async_exn (prover [])

let party_proof = Pickles.Side_loaded.Proof.of_proof party_proof

let party : Party.Graphql_repr.t =
  Party.to_graphql_repr ~call_depth:0
    { body = party_body; authorization = Proof party_proof }

let deploy_party_body : Party.Body.Graphql_repr.t =
  (* TODO: This is a pain. *)
  { Party.Body.Graphql_repr.dummy with
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

let deploy_party : Party.Graphql_repr.t =
  (* TODO: This is a pain. *)
  { body = deploy_party_body; authorization = Signature Signature.dummy }

let protocol_state_precondition = Zkapp_precondition.Protocol_state.accept

let ps =
  (* TODO: This is a pain. *)
  Parties.Call_forest.of_parties_list
    ~party_depth:(fun (p : Party.Graphql_repr.t) -> p.body.call_depth)
    [ deploy_party; party ]
  |> Parties.Call_forest.map ~f:Party.of_graphql_repr
  |> Parties.Call_forest.accumulate_hashes_predicated

let memo = Signed_command_memo.empty

let transaction_commitment : Parties.Transaction_commitment.t =
  (* TODO: This is a pain. *)
  let other_parties_hash = Parties.Call_forest.hash ps in
  Parties.Transaction_commitment.create ~other_parties_hash

let fee_payer =
  (* TODO: This is a pain. *)
  { Party.Fee_payer.body =
      { Party.Body.Fee_payer.dummy with
        public_key = pk_compressed
      ; fee = Currency.Fee.(of_int 100)
      ; protocol_state_precondition
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
    ; other_parties =
        Parties.Call_forest.of_parties_list [ deploy_party; party ]
          ~party_depth:(fun (p : Party.Graphql_repr.t) -> p.body.call_depth)
        |> Parties.Call_forest.map ~f:Party.of_graphql_repr
        |> Parties.Call_forest.accumulate_hashes'
    ; memo
    }

let () =
  Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
      let (_ : _) =
        Ledger.get_or_create_account ledger account_id
          (Account.create account_id
             Currency.Balance.(
               Option.value_exn (add_amount zero (Currency.Amount.of_int 500))) )
      in
      ignore (apply_parties ledger [ parties ] : Sparse_ledger.t) )
