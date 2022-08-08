open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Parties_segment = Transaction_snark.Parties_segment
module Statement = Transaction_snark.Statement

let%test_module "Initialize state test" =
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
          [ Zkapps_calls.initialize_rule pk_compressed
          ; Zkapps_calls.update_state_call_rule pk_compressed
          ; Zkapps_calls.add_rule pk_compressed
          ; Zkapps_calls.add_and_call_rule pk_compressed
          ] )

    type calls_kind =
      | Add_and_call of Snark_params.Tick.Run.Field.Constant.t * calls_kind
      | Add of Snark_params.Tick.Run.Field.Constant.t

    module P = (val p_module)

    let vk = Pickles.Side_loaded.Verification_key.of_compiled tag

    module Deploy_party = struct
      let party_body : Party.Body.t =
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
            { Party.Preconditions.network =
                Zkapp_precondition.Protocol_state.accept
            ; account = Accept
            }
        }

      let party : Party.t =
        (* TODO: This is a pain. *)
        { body = party_body; authorization = Signature Signature.dummy }
    end

    module Initialize_party = struct
      let party, _ = Async.Thread_safe.block_on_async_exn initialize_prover
    end

    module Update_state_party = struct
      let old_state = Snark_params.Tick.Field.zero

      let handler (calls_kind : calls_kind) old_state =
        let rec make_call calls_kind input :
            Zkapps_calls.Call_data.Output.Constant.t
            * Zkapp_call_forest.party
            * Zkapp_call_forest.t =
          match calls_kind with
          | Add increase_amount ->
              let tree, aux =
                Async.Thread_safe.block_on_async_exn
                  (add_prover
                     ~handler:(Zkapps_calls.add_handler input increase_amount) )
              in
              ( Option.value_exn aux
              , { data = tree.party; hash = tree.party_digest }
              , tree.calls )
          | Add_and_call (increase_amount, calls_kind) ->
              let tree, aux =
                Async.Thread_safe.block_on_async_exn
                  (add_and_call_prover
                     ~handler:
                       (Zkapps_calls.add_and_call_handler input increase_amount
                          (make_call calls_kind) ) )
              in
              ( Option.value_exn aux
              , { data = tree.party; hash = tree.party_digest }
              , tree.calls )
        in
        Zkapps_calls.update_state_handler old_state (make_call calls_kind)

      let party calls_kind =
        Async.Thread_safe.block_on_async_exn
          (update_state_call_prover ~handler:(handler calls_kind old_state))
        |> fst
    end

    let test_parties ?expected_failure parties =
      let memo = Signed_command_memo.empty in
      let transaction_commitment : Parties.Transaction_commitment.t =
        (* TODO: This is a pain. *)
        let other_parties_hash = Parties.Call_forest.hash parties in
        Parties.Transaction_commitment.create ~other_parties_hash
      in
      let fee_payer : Party.Fee_payer.t =
        { body =
            { Party.Body.Fee_payer.dummy with
              public_key = pk_compressed
            ; fee = Currency.Fee.(of_int 100)
            }
        ; authorization = Signature.dummy
        }
      in
      let memo_hash = Signed_command_memo.hash memo in
      let full_commitment =
        Parties.Transaction_commitment.create_complete transaction_commitment
          ~memo_hash
          ~fee_payer_hash:
            (Parties.Call_forest.Digest.Party.create
               (Party.of_fee_payer fee_payer) )
      in
      let sign_all ({ fee_payer; other_parties; memo } : Parties.t) : Parties.t
          =
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
                    Signature
                      (Schnorr.Chunked.sign sk
                         (Random_oracle.Input.Chunked.field commitment) )
                }
            | party ->
                party )
        in
        { fee_payer; other_parties; memo }
      in
      let parties : Parties.t =
        sign_all { fee_payer; other_parties = parties; memo }
      in
      Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
          let account =
            Account.create account_id
              Currency.Balance.(
                Option.value_exn (add_amount zero (Currency.Amount.of_int 500)))
          in
          let _, loc =
            Ledger.get_or_create_account ledger account_id account
            |> Or_error.ok_exn
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              check_parties_with_merges_exn ?expected_failure ledger [ parties ] ) ;
          Ledger.get ledger loc )

    let%test_unit "Initialize and update nonrecursive" =
      let increments =
        Array.init 1 ~f:(fun _ -> Snark_params.Tick.Field.random ())
      in
      let expected_result =
        Array.reduce_exn ~f:Snark_params.Tick.Field.add increments
      in
      let account =
        []
        |> Parties.Call_forest.cons_tree
             (Update_state_party.party (Add increments.(0)))
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties
      in
      let (first_state :: zkapp_state) =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      assert (Snark_params.Tick.Field.equal expected_result first_state) ;
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state

    let%test_unit "Initialize and update single recursive" =
      let increments =
        Array.init 2 ~f:(fun _ -> Snark_params.Tick.Field.random ())
      in
      let expected_result =
        Array.reduce_exn ~f:Snark_params.Tick.Field.add increments
      in
      let account =
        []
        |> Parties.Call_forest.cons_tree
             (Update_state_party.party
                (Add_and_call (increments.(0), Add increments.(1))) )
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties
      in
      let (first_state :: zkapp_state) =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      assert (Snark_params.Tick.Field.equal expected_result first_state) ;
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state

    let%test_unit "Initialize and update double recursive" =
      let increments =
        Array.init 3 ~f:(fun _ -> Snark_params.Tick.Field.random ())
      in
      let expected_result =
        Array.reduce_exn ~f:Snark_params.Tick.Field.add increments
      in
      let account =
        []
        |> Parties.Call_forest.cons_tree
             (Update_state_party.party
                (Add_and_call
                   ( increments.(0)
                   , Add_and_call (increments.(1), Add increments.(2)) ) ) )
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties
      in
      let (first_state :: zkapp_state) =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      assert (Snark_params.Tick.Field.equal expected_result first_state) ;
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state

    let%test_unit "Initialize and update triple recursive" =
      let increments =
        Array.init 4 ~f:(fun _ -> Snark_params.Tick.Field.random ())
      in
      let expected_result =
        Array.reduce_exn ~f:Snark_params.Tick.Field.add increments
      in
      let account =
        []
        |> Parties.Call_forest.cons_tree
             (Update_state_party.party
                (Add_and_call
                   ( increments.(0)
                   , Add_and_call
                       ( increments.(1)
                       , Add_and_call (increments.(2), Add increments.(3)) ) )
                ) )
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties
      in
      let (first_state :: zkapp_state) =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      assert (Snark_params.Tick.Field.equal expected_result first_state) ;
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state
  end )
