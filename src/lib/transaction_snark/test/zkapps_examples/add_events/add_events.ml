open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Nat = Pickles_types.Nat

let%test_module "Add events test" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let sk = Private_key.create ()

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    let account_id = Account_id.create pk_compressed Token_id.default

    let ( tag
        , _
        , p_module
        , Pickles.Provers.[ initialize_prover; add_events_prover ] ) =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Nat.N2)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"no events"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ ->
          [ Zkapps_add_events.initialize_rule pk_compressed
          ; Zkapps_add_events.update_events_rule pk_compressed
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
        { body = account_update_body
        ; authorization = Signature Signature.dummy
        }
    end

    module Initialize_account_update = struct
      let account_update, () =
        Async.Thread_safe.block_on_async_exn initialize_prover
    end

    module Add_events = struct
      let events =
        let open Zkapps_add_events in
        List.init num_events ~f:(fun outer ->
            Array.init event_length ~f:(fun inner ->
                Snark_params.Step.Field.of_int (outer + inner) ) )

      let account_update, () =
        Async.Thread_safe.block_on_async_exn
          (add_events_prover
             ~handler:(Zkapps_add_events.update_events_handler events) )
    end

    let test_zkapp_command ?expected_failure zkapp_command =
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
            ; fee = Currency.Fee.(of_int 100)
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
            Account.create account_id Currency.Balance.(of_int 500)
          in
          let _, loc =
            Ledger.get_or_create_account ledger account_id account
            |> Or_error.ok_exn
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              check_zkapp_command_with_merges_exn ?expected_failure ledger
                [ zkapp_command ] ) ;
          (zkapp_command, Ledger.get ledger loc) )

    module Events_verifier = Merkle_list_verifier.Make (struct
      type proof_elem = Mina_base.Zkapp_account.Event.t

      type hash = Snark_params.Step.Field.t [@@deriving equal]

      let hash (parent_hash : hash) (proof_elem : proof_elem) =
        let elem_hash = Mina_base.Zkapp_account.Event.hash proof_elem in
        Mina_base.Zkapp_account.Events.push_hash parent_hash elem_hash
    end)

    let%test_unit "Initialize" =
      let zkapp_command, account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
      in
      assert (Option.is_some account) ;
      let account_updates =
        Zkapp_command.Call_forest.to_list zkapp_command.account_updates
      in
      (* we haven't added any events, so should see default empty list *)
      List.iter account_updates ~f:(fun account_update ->
          assert (List.is_empty account_update.body.events) )

    let%test_unit "Initialize and add events" =
      let zkapp_command, account =
        []
        |> Zkapp_command.Call_forest.cons_tree Add_events.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
      in
      assert (Option.is_some account) ;
      let account_updates =
        Zkapp_command.Call_forest.to_list zkapp_command.account_updates
      in
      List.iteri account_updates ~f:(fun i account_update ->
          if i > 1 then assert (not @@ List.is_empty account_update.body.events)
          else assert (List.is_empty account_update.body.events) )

    let%test_unit "Initialize and add several events" =
      let zkapp_command, account =
        []
        |> Zkapp_command.Call_forest.cons_tree Add_events.account_update
        |> Zkapp_command.Call_forest.cons_tree Add_events.account_update
        |> Zkapp_command.Call_forest.cons_tree Add_events.account_update
        |> Zkapp_command.Call_forest.cons_tree
             Initialize_account_update.account_update
        |> Zkapp_command.Call_forest.cons Deploy_account_update.account_update
        |> test_zkapp_command
      in
      assert (Option.is_some account) ;
      let account_updates =
        Zkapp_command.Call_forest.to_list zkapp_command.account_updates
      in
      List.iteri account_updates ~f:(fun i account_update ->
          if i > 1 then assert (not @@ List.is_empty account_update.body.events)
          else assert (List.is_empty account_update.body.events) ) ;
      let zkapp_command_with_events = List.drop account_updates 2 in
      (* assemble big list of events from the AccountUpdates with events *)
      let all_events =
        List.concat_map zkapp_command_with_events ~f:(fun account_update ->
            account_update.body.events )
      in
      let all_events_hash = Mina_base.Zkapp_account.Events.hash all_events in
      (* verify the hash; Events.hash does a fold_right, so we use verify_right
         to match that
      *)
      match
        Events_verifier.verify_right ~init:Zkapp_account.Events.empty_hash
          all_events all_events_hash
      with
      | None ->
          failwith "Could not verify all_events hash"
      | Some _ ->
          ()
  end )
