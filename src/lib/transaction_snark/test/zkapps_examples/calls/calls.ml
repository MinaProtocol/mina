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

let%test_module "Composability test" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let sk = Private_key.create ()

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    let account_id = Account_id.create pk_compressed Token_id.default

    (* This is only value to use as an auxiliary_typ *)
    let option_typ (Typ typ : ('var, 'value) Impl.Typ.t) :
        ('var option, 'value option) Impl.Typ.t =
      Typ
        { var_to_fields =
            (function
            | None ->
                ([||], None)
            | Some x ->
                let fields, aux = typ.var_to_fields x in
                (fields, Some aux) )
        ; var_of_fields =
            (function
            | _, None ->
                None
            | fields, Some aux ->
                Some (typ.var_of_fields (fields, aux)) )
        ; value_to_fields =
            (function
            | None ->
                ([||], None)
            | Some x ->
                let fields, aux = typ.value_to_fields x in
                (fields, Some aux) )
        ; value_of_fields =
            (function
            | _, None ->
                None
            | fields, Some aux ->
                Some (typ.value_of_fields (fields, aux)) )
        ; size_in_field_elements = typ.size_in_field_elements
        ; constraint_system_auxiliary = (fun () -> None)
        ; check = (fun _ -> assert false)
        }

    (* Build the provers for the various rules. *)
    let ( tag
        , _
        , p_module
        , Pickles.Provers.
            [ initialize_prover
            ; update_state_call_prover
            ; add_prover
            ; add_and_call_prover
            ] ) =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:(option_typ Zkapps_calls.Call_data.Output.typ)
        ~branches:(module Nat.N4)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"empty_update"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ ->
          [ Zkapps_calls.Rules.Initialize_state.rule
          ; Zkapps_calls.Rules.Update_state.rule
          ; Zkapps_calls.Rules.Add.rule
          ; Zkapps_calls.Rules.Add_and_call.rule
          ] )

    (** The type of call to dispatch. *)
    type calls_kind =
      | Add_and_call of
          Account_update.Call_type.t
          * Snark_params.Tick.Run.Field.Constant.t
          * calls_kind
      | Add of Snark_params.Tick.Run.Field.Constant.t

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
      let account_update, _ =
        Async.Thread_safe.block_on_async_exn
          (initialize_prover
             ~handler:
               (Zkapps_calls.Rules.Initialize_state.handler pk_compressed) )
    end

    module Update_state_account_update = struct
      let old_state = Snark_params.Tick.Field.zero

      (** The request handler to use when running this account_update.

          This handler accepts a [calls_kind] and fills in the [Execute_call]
          handlers with either the 'add' prover or the 'add-and-call' prover,
          depending on the structure described by [calls_kind].

          When the desired call is 'add-and-call', this handler recursively
          builds the handler for the add-and-call circuit, inserting the
          behaviour for [Execute_call] according to the given [calls_kind].
      *)
      let handler (calls_kind : calls_kind) call_kind old_state =
        let rec make_call calls_kind caller input :
            Zkapps_calls.Call_data.Output.Constant.t
            * Zkapp_call_forest.account_update
            * Zkapp_call_forest.t =
          match calls_kind with
          | Add increase_amount ->
              (* Execute the 'add' rule. *)
              let handler =
                Zkapps_calls.Rules.Add.handler pk_compressed input caller
                  increase_amount
              in
              let tree, aux =
                Async.Thread_safe.block_on_async_exn (add_prover ~handler)
              in
              ( Option.value_exn aux
              , { data = tree.account_update
                ; hash = tree.account_update_digest
                }
              , tree.calls )
          | Add_and_call (call_type, increase_amount, calls_kind) ->
              (* Execute the 'add-and-call' rule *)
              let handler =
                (* Build the handler for the call in 'add-and-call' rule by
                   recursively calling this function on the remainder of
                   [calls_kind].
                *)
                let execute_call = make_call calls_kind in
                Zkapps_calls.Rules.Add_and_call.handler pk_compressed input
                  increase_amount caller call_type execute_call
              in
              let tree, aux =
                Async.Thread_safe.block_on_async_exn
                  (add_and_call_prover ~handler)
              in
              ( Option.value_exn aux
              , { data = tree.account_update
                ; hash = tree.account_update_digest
                }
              , tree.calls )
        in
        Zkapps_calls.Rules.Update_state.handler pk_compressed old_state
          call_kind (make_call calls_kind)

      let account_update calls_kind call_kind =
        Async.Thread_safe.block_on_async_exn
          (update_state_call_prover
             ~handler:(handler calls_kind call_kind old_state) )
        |> fst
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
            ; fee = Currency.Fee.(nanomina_exn 100)
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
                Option.value_exn (add_amount zero (Currency.Amount.nanomina_exn 500)))
          in
          let _, loc =
            Ledger.get_or_create_account ledger account_id account
            |> Or_error.ok_exn
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              check_zkapp_command_with_merges_exn ?expected_failure ledger
                [ zkapp_command ] ) ;
          Ledger.get ledger loc )

    let test_recursive num_calls call_kind =
      let increments =
        Array.init num_calls ~f:(fun _ -> Snark_params.Tick.Field.random ())
      in
      let calls_kind =
        (* Recursively call [i+1] times. *)
        let rec go i =
          if i = 0 then Add increments.(0)
          else Add_and_call (call_kind, increments.(i), go (i - 1))
        in
        go (num_calls - 1)
      in
      let expected_result =
        Array.reduce_exn ~f:Snark_params.Tick.Field.add increments
      in
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             (Update_state_account_update.account_update calls_kind call_kind)
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
      in
      let (first_state :: zkapp_state) =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      assert (Snark_params.Tick.Field.equal expected_result first_state) ;
      (* Check that the rest of the state is unmodified. *)
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state

    let%test_unit "Initialize and update nonrecursive" = test_recursive 1 Call

    let%test_unit "Initialize and update single recursive" =
      test_recursive 2 Call

    let%test_unit "Initialize and update double recursive" =
      test_recursive 3 Call

    let%test_unit "Initialize and update triple recursive" =
      test_recursive 4 Call

    let%test_unit "Initialize and update nonrecursive" =
      test_recursive 1 Delegate_call

    let%test_unit "Initialize and update single recursive" =
      test_recursive 2 Delegate_call

    let%test_unit "Initialize and update double recursive" =
      test_recursive 3 Delegate_call

    let%test_unit "Initialize and update triple recursive" =
      test_recursive 4 Delegate_call
  end )
