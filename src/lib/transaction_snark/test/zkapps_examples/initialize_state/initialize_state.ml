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

let%test_module "Initialize state test" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let sk = Private_key.create ()

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    let account_id = Account_id.create pk_compressed Token_id.default

    let ( tag
        , _
        , p_module
        , Pickles.Provers.[ initialize_prover; update_state_prover ] ) =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Nat.N2)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"empty_update"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ ->
          [ Zkapps_initialize_state.initialize_rule pk_compressed
          ; Zkapps_initialize_state.update_state_rule pk_compressed
          ] )

    module P = (val p_module)

    let vk = Pickles.Side_loaded.Verification_key.of_compiled tag

    module Deploy_account_update = struct
      let account_update_body : Account_update.Body.t =
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
                  ; set_permissions = Proof
                  ; set_verification_key = Proof
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

      let account_update : Account_update.t =
        (* TODO: This is a pain. *)
        { body = account_update_body
        ; authorization = Signature Signature.dummy
        }
    end

    module Initialize_account_update = struct
      let account_update, () =
        Async.Thread_safe.block_on_async_exn initialize_prover
    end

    module Update_state_account_update = struct
      let new_state = List.init 8 ~f:(fun _ -> Snark_params.Tick.Field.one)

      let account_update, () =
        Async.Thread_safe.block_on_async_exn
          (update_state_prover
             ~handler:(Zkapps_initialize_state.update_state_handler new_state) )
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
            ; fee = Currency.Fee.(nanomina 100)
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
                  (add_amount zero (Currency.Amount.nanomina 500)))
          in
          let _, loc =
            Ledger.get_or_create_account ledger account_id account
            |> Or_error.ok_exn
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              check_zkapp_command_with_merges_exn ?expected_failure ledger
                [ zkapp_command ] ) ;
          Ledger.get ledger loc )

    let%test_unit "Initialize" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
      in
      let zkapp_state =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state

    let%test_unit "Initialize and update" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Update_state_account_update.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
      in
      let zkapp_state =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal one) x))
        zkapp_state

    let%test_unit "Initialize and multiple update" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Update_state_account_update.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Update_state_account_update.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
      in
      let zkapp_state =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal one) x))
        zkapp_state

    let%test_unit "Update without initialize fails" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Update_state_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
             ~expected_failure:Account_proved_state_precondition_unsatisfied
      in
      assert (Option.is_none (Option.value_exn account).zkapp)

    let%test_unit "Double initialize fails" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
             ~expected_failure:Account_proved_state_precondition_unsatisfied
      in
      assert (Option.is_none (Option.value_exn account).zkapp)

    let%test_unit "Initialize after update fails" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Update_state_account_update.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
             ~expected_failure:Account_proved_state_precondition_unsatisfied
      in
      assert (Option.is_none (Option.value_exn account).zkapp)

    let%test_unit "Initialize without deploy fails" =
      let account =
        Or_error.try_with (fun () ->
            (* Raises an exception due to verifying a proof without a valid vk
               in the account.
            *)
            []
            |> Zkapp_command.Call_forest.cons_tree
                 Update_state_account_update.account_update
            |> Zkapp_command.Call_forest.cons_tree
                 Initialize_account_update.account_update
            |> test_zkapp_command )
      in
      assert (Or_error.is_error account)
  end )
