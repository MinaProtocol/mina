open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Nat = Pickles_types.Nat

let%test_module "Actions test" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let sk = Private_key.create ()

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    let account_id = Account_id.create pk_compressed Token_id.default

    let ( tag
        , _
        , p_module
        , Pickles.Provers.[ initialize_prover; add_actions_prover ] ) =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Nat.N2)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"no actions"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ ->
          [ Zkapps_actions.initialize_rule pk_compressed
          ; Zkapps_actions.update_actions_rule pk_compressed
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
                Set { data = vk; hash = Zkapp_account.digest_vk vk }
            ; permissions =
                Set
                  { edit_state = Proof
                  ; send = Signature
                  ; receive = Signature
                  ; access = None
                  ; set_delegate = Proof
                  ; set_permissions = Proof
                  ; set_verification_key = (Proof, Protocol_version.current)
                  ; set_zkapp_uri = Proof
                  ; edit_action_state = Proof
                  ; set_token_symbol = Proof
                  ; increment_nonce = Signature
                  ; set_voting_for = Proof
                  ; set_timing = Proof
                  }
            }
        ; use_full_commitment = true
        ; preconditions =
            { Account_update.Preconditions.network =
                Zkapp_precondition.Protocol_state.accept
            ; account = Accept
            ; valid_while = Ignore
            }
        ; authorization_kind = Signature
        }

      let account_update : Account_update.t =
        { body = account_update_body
        ; authorization = Signature Signature.dummy
        }
    end

    module Initialize_account_update = struct
      let account_update, () =
        Async.Thread_safe.block_on_async_exn initialize_prover
    end

    module Add_actions = struct
      let actions =
        let open Zkapps_actions in
        List.init num_events ~f:(fun outer ->
            Array.init event_length ~f:(fun inner ->
                Snark_params.Tick.Field.of_int (outer + inner) ) )

      let account_update, () =
        Async.Thread_safe.block_on_async_exn
          (add_actions_prover
             ~handler:(Zkapps_actions.update_actions_handler actions) )
    end

    let test_zkapp_command ?expected_failure ?state_body ?global_slot
        ?(fee_payer_nonce = 0) ~ledger zkapp_command =
      let memo = Signed_command_memo.empty in
      let transaction_commitment : Zkapp_command.Transaction_commitment.t =
        let account_updates_hash =
          Zkapp_command.Call_forest.hash zkapp_command
        in
        Zkapp_command.Transaction_commitment.create ~account_updates_hash
      in
      let fee_payer : Account_update.Fee_payer.t =
        { body =
            { Account_update.Body.Fee_payer.dummy with
              public_key = pk_compressed
            ; fee = Currency.Fee.(of_nanomina_int_exn 50)
            ; nonce = Account.Nonce.of_int fee_payer_nonce
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
      let account =
        Account.create account_id Currency.Balance.(of_nanomina_int_exn 500)
      in
      let _, loc =
        Ledger.get_or_create_account ledger account_id account
        |> Or_error.ok_exn
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          check_zkapp_command_with_merges_exn ?state_body ?global_slot
            ?expected_failure ledger [ zkapp_command ] ) ;
      (zkapp_command, Ledger.get ledger loc)

    let create_ledger () = Ledger.create ~depth:ledger_depth ()

    let action_state_elts_of_account (account_opt : Account.t option) =
      let zkapp = Option.value_exn (Option.value_exn account_opt).zkapp in
      let action_state = zkapp.action_state in
      let last_action_slot = zkapp.last_action_slot in
      (Pickles_types.Vector.Vector_5.to_list action_state, last_action_slot)

    let%test_unit "Initialize" =
      let zkapp_command, account =
        let ledger = create_ledger () in
        []
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command ~ledger
      in
      assert (Option.is_some account) ;
      let account_updates =
        Zkapp_command.Call_forest.to_list zkapp_command.account_updates
      in
      (* we haven't added any sequence events *)
      List.iter account_updates ~f:(fun account_update ->
          assert (List.is_empty account_update.body.actions) )

    let%test_unit "Initialize and add sequence events" =
      let zkapp_command0, account0 =
        let ledger = create_ledger () in
        []
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command ~ledger
             ~global_slot:Mina_numbers.Global_slot_since_genesis.zero
      in
      let account_updates0 =
        Zkapp_command.Call_forest.to_list zkapp_command0.account_updates
      in
      List.iter account_updates0 ~f:(fun account_update ->
          assert (List.is_empty account_update.body.actions) ) ;
      assert (Option.is_some account0) ;
      (* action state unmodified *)
      let action_state_elts0, last_action_slot0 =
        action_state_elts_of_account account0
      in
      List.iter action_state_elts0 ~f:(fun elt ->
          assert (
            Impl.Field.Constant.equal elt
              Zkapp_account.Actions.empty_state_element ) ) ;
      (* last action slot is 0 *)
      assert (
        Mina_numbers.Global_slot_since_genesis.(equal zero) last_action_slot0 ) ;
      let zkapp_command1, account1 =
        let ledger = create_ledger () in
        []
        |> Zkapp_command.Call_forest.cons_tree Add_actions.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command ~ledger
             ~global_slot:Mina_numbers.Global_slot_since_genesis.zero
      in
      assert (Option.is_some account1) ;
      let account_updates1 =
        Zkapp_command.Call_forest.to_list zkapp_command1.account_updates
      in
      List.iteri account_updates1 ~f:(fun i account_update ->
          if i > 1 then assert (not @@ List.is_empty account_update.body.actions)
          else assert (List.is_empty account_update.body.actions) ) ;
      let action_state_elts1, last_action_slot1 =
        action_state_elts_of_account account1
      in
      (* we changed the 0th action state element *)
      List.iteri action_state_elts1 ~f:(fun i elt ->
          if i = 0 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Actions.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Actions.empty_state_element ) ) ;
      (* last action slot still 0 *)
      assert (
        Mina_numbers.Global_slot_since_genesis.(equal zero) last_action_slot1 )

    let%test_unit "Add sequence events in different slots" =
      let ledger = create_ledger () in
      let slot1 = Mina_numbers.Global_slot_since_genesis.of_int 1 in
      let _zkapp_command0, account0 =
        []
        |> Zkapp_command.Call_forest.cons_tree Add_actions.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command ~global_slot:slot1 ~ledger
      in
      assert (Option.is_some account0) ;
      let action_state_elts0, last_action_slot0 =
        action_state_elts_of_account account0
      in
      (* we changed the 0th action state element
         there's a shift, but because the 0th element
         was the default, all other elements remain
         the default
      *)
      List.iteri action_state_elts0 ~f:(fun i elt ->
          if i = 0 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Actions.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Actions.empty_state_element ) ) ;
      (* action slot is 1 *)
      assert (
        Mina_numbers.Global_slot_since_genesis.equal slot1 last_action_slot0 ) ;
      let slot2 = Mina_numbers.Global_slot_since_genesis.of_int 2 in
      let _zkapp_command1, account1 =
        []
        |> Zkapp_command.Call_forest.cons_tree Add_actions.account_update
        |> test_zkapp_command ~global_slot:slot2 ~fee_payer_nonce:1 ~ledger
      in
      assert (Option.is_some account1) ;
      let action_state_elts1, last_action_slot1 =
        action_state_elts_of_account account1
      in
      (* we changed the 0th action state element
         this time the shift also changes the 1st element
      *)
      List.iteri action_state_elts1 ~f:(fun i elt ->
          if i >= 0 && i <= 1 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Actions.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Actions.empty_state_element ) ) ;
      (* check the shifted elements *)
      for i = 1 to 4 do
        let last_elt = List.nth_exn action_state_elts0 (i - 1) in
        let curr_elt = List.nth_exn action_state_elts1 i in
        assert (Impl.Field.Constant.equal last_elt curr_elt)
      done ;
      (* action slot is 2 *)
      assert (
        Mina_numbers.Global_slot_since_genesis.equal slot2 last_action_slot1 ) ;
      let slot3 = Mina_numbers.Global_slot_since_genesis.of_int 3 in
      let _zkapp_command2, account2 =
        []
        |> Zkapp_command.Call_forest.cons_tree Add_actions.account_update
        |> test_zkapp_command ~global_slot:slot3 ~fee_payer_nonce:2 ~ledger
      in
      assert (Option.is_some account2) ;
      let action_state_elts2, last_action_slot2 =
        action_state_elts_of_account account2
      in
      (* we changed the 0th action state element
         the shift also has changed the 1st, 2nd elements
      *)
      List.iteri action_state_elts2 ~f:(fun i elt ->
          if i >= 0 && i <= 2 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Actions.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Actions.empty_state_element ) ) ;
      (* check the shifted elements *)
      for i = 1 to 4 do
        let last_elt = List.nth_exn action_state_elts1 (i - 1) in
        let curr_elt = List.nth_exn action_state_elts2 i in
        assert (Impl.Field.Constant.equal last_elt curr_elt)
      done ;
      (* action slot is 3 *)
      assert (
        Mina_numbers.Global_slot_since_genesis.equal slot3 last_action_slot2 )
  end )
