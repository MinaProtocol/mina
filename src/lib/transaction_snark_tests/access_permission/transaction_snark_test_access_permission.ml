open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

let%test_module "Access permission tests" =
  ( module struct
    let proof_cache =
      Result.ok_or_failwith @@ Pickles.Proof_cache.of_yojson
      @@ Yojson.Safe.from_file "proof_cache.json"

    let () = Transaction_snark.For_tests.set_proof_cache proof_cache

    let () = Backtrace.elide := false

    let sk = Quickcheck.random_value Private_key.gen

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    let account_id = Account_id.create pk_compressed Token_id.default

    let tag, _, p_module, Pickles.Provers.[ prover ] =
      Zkapps_examples.compile () ~cache:Cache_dir.cache ~proof_cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Nat.N1)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"empty_update"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ -> [ Zkapps_empty_update.rule pk_compressed ])

    module P = (val p_module)

    let vk = Pickles.Side_loaded.Verification_key.of_compiled tag

    let vk_hash = Mina_base.Verification_key_wire.digest_vk vk

    let ({ account_update; _ } : _ Zkapp_command.Call_forest.tree), () =
      Async.Thread_safe.block_on_async_exn prover

    let memo = Signed_command_memo.empty

    let run_test ?expected_failure auth_kind access_permission =
      let account_update : Account_update.t =
        match auth_kind with
        | Account_update.Authorization_kind.Proof _ ->
            { body = { account_update.body with authorization_kind = auth_kind }
            ; authorization = account_update.authorization
            }
        | Account_update.Authorization_kind.Signature ->
            { body =
                { account_update.body with
                  authorization_kind = auth_kind
                ; increment_nonce = true
                ; preconditions =
                    { account =
                        Zkapp_precondition.Account.nonce
                          Mina_numbers.Account_nonce.(succ zero)
                    ; network = account_update.body.preconditions.network
                    ; valid_while = Ignore
                    }
                }
            ; authorization = Signature Signature.dummy
            }
        | Account_update.Authorization_kind.None_given ->
            { body = { account_update.body with authorization_kind = auth_kind }
            ; authorization = None_given
            }
      in
      let deploy_account_update_body : Account_update.Body.t =
        (* TODO: This is a pain. *)
        { Account_update.Body.dummy with
          public_key = pk_compressed
        ; update =
            { Account_update.Update.dummy with
              permissions =
                Set { Permissions.user_default with access = access_permission }
            ; verification_key = Set { data = vk; hash = vk_hash }
            }
        ; preconditions =
            { Account_update.Preconditions.network =
                Zkapp_precondition.Protocol_state.accept
            ; account = Zkapp_precondition.Account.accept
            ; valid_while = Ignore
            }
        ; may_use_token = No
        ; use_full_commitment = true
        ; authorization_kind = Signature
        }
      in
      let deploy_account_update : Account_update.t =
        (* TODO: This is a pain. *)
        { body = deploy_account_update_body
        ; authorization = Signature Signature.dummy
        }
      in
      let account_updates =
        []
        |> Zkapp_command.Call_forest.cons account_update
        |> Zkapp_command.Call_forest.cons deploy_account_update
      in
      let transaction_commitment : Zkapp_command.Transaction_commitment.t =
        (* TODO: This is a pain. *)
        let account_updates_hash =
          Zkapp_command.Call_forest.hash account_updates
        in
        Zkapp_command.Transaction_commitment.create ~account_updates_hash
      in
      let fee_payer =
        (* TODO: This is a pain. *)
        { Account_update.Fee_payer.body =
            { Account_update.Body.Fee_payer.dummy with
              public_key = pk_compressed
            ; fee = Currency.Fee.of_nanomina_int_exn 100
            }
        ; authorization = Signature.dummy
        }
      in
      let full_commitment =
        (* TODO: This is a pain. *)
        Zkapp_command.Transaction_commitment.create_complete
          transaction_commitment
          ~memo_hash:(Signed_command_memo.hash memo)
          ~fee_payer_hash:
            (Zkapp_command.Digest.Account_update.create
               (Account_update.of_fee_payer fee_payer) )
      in
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
      in
      let zkapp_command : Zkapp_command.t =
        sign_all
          { fee_payer =
              { body = fee_payer.body; authorization = Signature.dummy }
          ; account_updates
          ; memo
          }
      in
      Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
          let (_ : _) =
            Ledger.get_or_create_account ledger account_id
              (Account.create account_id
                 Currency.Balance.(
                   Option.value_exn
                     (add_amount zero (Currency.Amount.of_nanomina_int_exn 500))) )
          in
          Async.Thread_safe.block_on_async_exn
          @@ fun () ->
          check_zkapp_command_with_merges_exn ?expected_failure ledger
            [ zkapp_command ] )

    let%test_unit "None_given with None" = run_test None_given None

    let%test_unit "Proof with None" = run_test (Proof vk_hash) None

    let%test_unit "Signature with None" = run_test Signature None

    let%test_unit "None_given with Either" =
      run_test
        ~expected_failure:(Update_not_permitted_access, Pass_2)
        None_given Either

    let%test_unit "Proof with Either" = run_test (Proof vk_hash) Either

    let%test_unit "Signature with Either" = run_test Signature Either

    let%test_unit "None_given with Proof" =
      run_test
        ~expected_failure:(Update_not_permitted_access, Pass_2)
        None_given Proof

    let%test_unit "Proof with Proof" = run_test (Proof vk_hash) Proof

    let%test_unit "Signature with Proof" =
      run_test
        ~expected_failure:(Update_not_permitted_access, Pass_2)
        Signature Proof

    let%test_unit "None_given with Signature" =
      run_test
        ~expected_failure:(Update_not_permitted_access, Pass_2)
        None_given Signature

    let%test_unit "Proof with Signature" =
      run_test
        ~expected_failure:(Update_not_permitted_access, Pass_2)
        (Proof vk_hash) Signature

    let%test_unit "Signature with Signature" = run_test Signature Signature

    let () =
      match Sys.getenv_opt "PROOF_CACHE_OUT" with
      | Some path ->
          Yojson.Safe.to_file path @@ Pickles.Proof_cache.to_yojson proof_cache
      | None ->
          ()
  end )
