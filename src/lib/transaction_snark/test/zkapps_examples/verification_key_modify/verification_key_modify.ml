open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment
module Statement = Transaction_snark.Statement

module Make_trivial_rule (Id : sig
  val id : int

  val pk_compressed : Public_key.Compressed.t
end) =
struct
  open Snark_params.Tick.Run

  (** The request handler for the rule. *)
  let handler (Snarky_backendless.Request.With { request; respond }) =
    match request with _ -> respond Unhandled

  let main input =
    let public_key =
      exists Public_key.Compressed.typ ~compute:(fun () -> Id.pk_compressed)
    in
    Zkapps_examples.wrap_main ~public_key
      (fun account_update ->
        let id = Field.Constant.of_int Id.id in
        let x = exists Field.typ ~compute:(fun () -> id) in
        let y = Field.constant id in
        Field.Assert.equal x y ;
        account_update#set_state 0 x )
      input

  let rule : _ Pickles.Inductive_rule.t =
    { identifier = sprintf "Trivial %d" Id.id
    ; prevs = []
    ; main
    ; uses_lookup = false
    }
end

let%test_module "Verification key modify mid txn" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let sk = Private_key.create ()

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    module Trivial_rule1 = Make_trivial_rule (struct
      let id = 1

      let pk_compressed = pk_compressed
    end)

    module Trivial_rule2 = Make_trivial_rule (struct
      let id = 2

      let pk_compressed = pk_compressed
    end)

    let account_id = Account_id.create pk_compressed Token_id.default

    (* Build the provers for the various rules. *)
    let tag1, _, _, Pickles.Provers.[ trivial_prover1 ] =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Nat.N1)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"trivial1"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ -> [ Trivial_rule1.rule ])

    let tag2, _, _, Pickles.Provers.[ trivial_prover2 ] =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Nat.N1)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"trivial2"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ -> [ Trivial_rule2.rule ])

    let vk1 = Pickles.Side_loaded.Verification_key.of_compiled tag1

    let vk2 = Pickles.Side_loaded.Verification_key.of_compiled tag2

    module Deploy_account_update = struct
      let account_update_body (vk : Side_loaded_verification_key.t) :
          Account_update.Body.t =
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
            ; permissions =
                Set
                  { edit_state = Proof
                  ; send = Proof
                  ; receive = Proof
                  ; set_delegate = Proof
                  ; set_permissions = Signature
                  ; set_verification_key = Signature
                  ; set_zkapp_uri = Proof
                  ; edit_sequence_state = Proof
                  ; set_token_symbol = Proof
                  ; increment_nonce = Proof
                  ; set_voting_for = Proof
                  }
            }
        ; use_full_commitment = true
        ; preconditions =
            { Account_update.Preconditions.network =
                Zkapp_precondition.Protocol_state.accept
            ; account = Accept
            }
        ; authorization_kind = Signature
        }

      let account_update (vk : Side_loaded_verification_key.t) :
          Account_update.t =
        (* TODO: This is a pain. *)
        { body = account_update_body vk
        ; authorization = Signature Signature.dummy
        }
    end

    module Trivial_account_update1 = struct
      let account_update, _ =
        Async.Thread_safe.block_on_async_exn
          (trivial_prover1 ~handler:Trivial_rule1.handler)
    end

    module Trivial_account_update2 = struct
      let account_update, _ =
        Async.Thread_safe.block_on_async_exn
          (trivial_prover2 ~handler:Trivial_rule2.handler)
    end

    let test_zkapp_command ?expected_failure zkapp_command =
      let memo = Signed_command_memo.empty in
      let transaction_commitment : Zkapp_command.Transaction_commitment.t =
        (* TODO: This is a pain. *)
        let account_updates_hash =
          Zkapp_command.Call_forest.hash zkapp_command
        in
        Zkapp_command.Transaction_commitment.create ~account_updates_hash
      in
      let fee_payer : Account_update.Fee_payer.t =
        { body =
            { Account_update.Body.Fee_payer.dummy with
              public_key = pk_compressed
            ; fee = Currency.Fee.(of_nanomina_int_exn 100)
            }
        ; authorization = Signature.dummy
        }
      in
      let memo_hash = Signed_command_memo.hash memo in
      let full_commitment =
        Zkapp_command.Transaction_commitment.create_complete
          transaction_commitment ~memo_hash
          ~fee_payer_hash:
            (Zkapp_command.Call_forest.Digest.Account_update.create
               (Account_update.of_fee_payer fee_payer) )
      in
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
                    Signature
                      (Schnorr.Chunked.sign sk
                         (Random_oracle.Input.Chunked.field commitment) )
                }
            | account_update ->
                account_update )
        in
        { fee_payer; account_updates; memo }
      in
      let zkapp_command : Zkapp_command.t =
        sign_all { fee_payer; account_updates = zkapp_command; memo }
      in
      Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
          let account =
            Account.create account_id
              Currency.Balance.(
                Option.value_exn
                  (add_amount zero (Currency.Amount.of_nanomina_int_exn 500)))
          in
          let _, loc =
            Ledger.get_or_create_account ledger account_id account
            |> Or_error.ok_exn
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              check_zkapp_command_with_merges_exn ?expected_failure ledger
                [ zkapp_command ] ) ;
          Ledger.get ledger loc )

    let%test_unit "Verification key swapped, later account updates run, \
                   transactions succeeds" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Trivial_account_update2.account_update
        |> Zkapp_command.Call_forest.cons
             (Deploy_account_update.account_update vk2)
        |> Zkapp_command.Call_forest.cons_tree
             Trivial_account_update1.account_update
        |> Zkapp_command.Call_forest.cons
             (Deploy_account_update.account_update vk1)
        |> test_zkapp_command
      in
      let (first_state :: _zkapp_state) =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      (* This should succeed and the end result is the state should be set to 2 *)
      assert (
        Snark_params.Tick.Field.equal
          (Snark_params.Tick.Field.of_int 2)
          first_state )

    let%test_unit "Verification key swapped, later account updates bad, \
                   transactions fails" =
      let _account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Trivial_account_update1.account_update
        |> Zkapp_command.Call_forest.cons
             (Deploy_account_update.account_update vk2)
        |> Zkapp_command.Call_forest.cons_tree
             Trivial_account_update1.account_update
        |> Zkapp_command.Call_forest.cons
             (Deploy_account_update.account_update vk1)
        |> test_zkapp_command
             ~expected_failure:
               Transaction_status.Failure.update_not_permitted_verification_key
      in
      ()
  end )
