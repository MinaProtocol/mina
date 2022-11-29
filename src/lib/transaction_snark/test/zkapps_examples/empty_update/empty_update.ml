open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

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

let account_update, () = Async.Thread_safe.block_on_async_exn prover

let deploy_account_update_body : Account_update.Body.t =
  (* TODO: This is a pain. *)
  { Account_update.Body.dummy with
    public_key = pk_compressed
  ; update =
      { Account_update.Update.dummy with
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
      { Account_update.Preconditions.network =
          Zkapp_precondition.Protocol_state.accept
      ; account = Accept
      }
  ; caller = Token_id.default
  ; use_full_commitment = true
  ; authorization_kind = Signature
  }

let deploy_account_update : Account_update.t =
  (* TODO: This is a pain. *)
  { body = deploy_account_update_body
  ; authorization = Signature Signature.dummy
  }

let account_updates =
  []
  |> Zkapp_command.Call_forest.cons_tree account_update
  |> Zkapp_command.Call_forest.cons deploy_account_update

let memo = Signed_command_memo.empty

let transaction_commitment : Zkapp_command.Transaction_commitment.t =
  (* TODO: This is a pain. *)
  let account_updates_hash = Zkapp_command.Call_forest.hash account_updates in
  Zkapp_command.Transaction_commitment.create ~account_updates_hash

let fee_payer =
  (* TODO: This is a pain. *)
  { Account_update.Fee_payer.body =
      { Account_update.Body.Fee_payer.dummy with
        public_key = pk_compressed
      ; fee = Currency.Fee.(of_int 100)
      }
  ; authorization = Signature.dummy
  }

let full_commitment =
  (* TODO: This is a pain. *)
  Zkapp_command.Transaction_commitment.create_complete transaction_commitment
    ~memo_hash:(Signed_command_memo.hash memo)
    ~fee_payer_hash:
      (Zkapp_command.Digest.Account_update.create
         (Account_update.of_fee_payer fee_payer) )

(* TODO: Make this better. *)
let sign_all ({ fee_payer; account_updates; memo } : Zkapp_command.t) :
    Zkapp_command.t =
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
  let account_updates =
    Zkapp_command.Call_forest.map account_updates ~f:(function
      | ({ body = { public_key; use_full_commitment; _ }
         ; authorization = Signature _
         } as account_update :
          Account_update.t )
        when Public_key.Compressed.equal public_key pk_compressed ->
          let commitment =
            if use_full_commitment then full_commitment
            else transaction_commitment
          in
          { account_update with
            authorization =
              Control.Signature
                (Schnorr.Chunked.sign sk
                   (Random_oracle.Input.Chunked.field commitment) )
          }
      | account_update ->
          account_update )
  in
  { fee_payer; account_updates; memo }

let zkapp_command : Zkapp_command.t =
  sign_all
    { fee_payer = { body = fee_payer.body; authorization = Signature.dummy }
    ; account_updates
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
      ignore (apply_zkapp_command ledger [ zkapp_command ] : Sparse_ledger.t) )
