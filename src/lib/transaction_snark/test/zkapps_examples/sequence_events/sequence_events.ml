open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Nat = Pickles_types.Nat

let%test_module "Sequence events test" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let sk = Private_key.create ()

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    let account_id = Account_id.create pk_compressed Token_id.default

    let ( tag
        , _
        , p_module
        , Pickles.Provers.[ initialize_prover; add_sequence_events_prover ] ) =
      Zkapps_examples.compile () ~cache:Cache_dir.cache
        ~auxiliary_typ:Impl.Typ.unit
        ~branches:(module Nat.N2)
        ~max_proofs_verified:(module Nat.N0)
        ~name:"no sequence events"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants )
        ~choices:(fun ~self:_ ->
          [ Zkapps_sequence_events.initialize_rule pk_compressed
          ; Zkapps_sequence_events.update_sequence_events_rule pk_compressed
          ] )

    module P = (val p_module)

    let vk = Pickles.Side_loaded.Verification_key.of_compiled tag

    module Deploy_party = struct
      let party_body : Party.Body.t =
        { Party.Body.dummy with
          public_key = pk_compressed
        ; update =
            { Party.Update.dummy with
              verification_key =
                Set { data = vk; hash = Zkapp_account.digest_vk vk }
            ; permissions =
                Set
                  { edit_state = Proof
                  ; send = Signature
                  ; receive = Signature
                  ; set_delegate = Proof
                  ; set_permissions = Proof
                  ; set_verification_key = Proof
                  ; set_zkapp_uri = Proof
                  ; edit_sequence_state = Proof
                  ; set_token_symbol = Proof
                  ; increment_nonce = Signature
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
        { body = party_body; authorization = Signature Signature.dummy }
    end

    module Initialize_party = struct
      let party, () = Async.Thread_safe.block_on_async_exn initialize_prover
    end

    module Add_sequence_events = struct
      let sequence_events =
        let open Zkapps_sequence_events in
        List.init num_events ~f:(fun outer ->
            Array.init event_length ~f:(fun inner ->
                Snark_params.Tick.Field.of_int (outer + inner) ) )

      let party, () =
        Async.Thread_safe.block_on_async_exn
          (add_sequence_events_prover
             ~handler:
               (Zkapps_sequence_events.update_sequence_events_handler
                  sequence_events ) )
    end

    let test_parties ?expected_failure ?state_body ?(fee_payer_nonce = 0)
        ~ledger parties =
      let memo = Signed_command_memo.empty in
      let transaction_commitment : Parties.Transaction_commitment.t =
        let other_parties_hash = Parties.Call_forest.hash parties in
        Parties.Transaction_commitment.create ~other_parties_hash
      in
      let fee_payer : Party.Fee_payer.t =
        { body =
            { Party.Body.Fee_payer.dummy with
              public_key = pk_compressed
            ; fee = Currency.Fee.(nanomina 50)
            ; nonce = Account.Nonce.of_int fee_payer_nonce
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
      let account = Account.create account_id Currency.Balance.(nanomina 500) in
      let _, loc =
        Ledger.get_or_create_account ledger account_id account
        |> Or_error.ok_exn
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          check_parties_with_merges_exn ?state_body ?expected_failure ledger
            [ parties ] ) ;
      (parties, Ledger.get ledger loc)

    let create_ledger () = Ledger.create ~depth:ledger_depth ()

    let seq_state_elts_of_account (account_opt : Account.t option) =
      let zkapp = Option.value_exn (Option.value_exn account_opt).zkapp in
      let seq_state = zkapp.sequence_state in
      let last_seq_slot = zkapp.last_sequence_slot in
      (Pickles_types.Vector.Vector_5.to_list seq_state, last_seq_slot)

    let%test_unit "Initialize" =
      let parties, account =
        let ledger = create_ledger () in
        []
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties ~ledger
      in
      assert (Option.is_some account) ;
      let other_parties = Parties.Call_forest.to_list parties.other_parties in
      (* we haven't added any sequence events *)
      List.iter other_parties ~f:(fun party ->
          assert (List.is_empty party.body.sequence_events) )

    let%test_unit "Initialize and add sequence events" =
      let parties0, account0 =
        let ledger = create_ledger () in
        []
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties ~ledger
      in
      let other_parties0 = Parties.Call_forest.to_list parties0.other_parties in
      List.iter other_parties0 ~f:(fun party ->
          assert (List.is_empty party.body.sequence_events) ) ;
      assert (Option.is_some account0) ;
      (* sequence state unmodified *)
      let seq_state_elts0, last_seq_slot0 =
        seq_state_elts_of_account account0
      in
      List.iter seq_state_elts0 ~f:(fun elt ->
          assert (
            Impl.Field.Constant.equal elt
              Zkapp_account.Sequence_events.empty_state_element ) ) ;
      (* last seq slot is 0 *)
      assert (Mina_numbers.Global_slot.(equal zero) last_seq_slot0) ;
      let parties1, account1 =
        let ledger = create_ledger () in
        []
        |> Parties.Call_forest.cons_tree Add_sequence_events.party
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties ~ledger
      in
      assert (Option.is_some account1) ;
      let other_parties1 = Parties.Call_forest.to_list parties1.other_parties in
      List.iteri other_parties1 ~f:(fun i party ->
          if i > 1 then assert (not @@ List.is_empty party.body.sequence_events)
          else assert (List.is_empty party.body.sequence_events) ) ;
      let seq_state_elts1, last_seq_slot1 =
        seq_state_elts_of_account account1
      in
      (* we changed the 0th sequence state element *)
      List.iteri seq_state_elts1 ~f:(fun i elt ->
          if i = 0 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Sequence_events.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Sequence_events.empty_state_element ) ) ;
      (* last seq slot still 0 *)
      assert (Mina_numbers.Global_slot.(equal zero) last_seq_slot1)

    let%test_unit "Add sequence events in different slots" =
      let make_state_body slot =
        let open Mina_state.Protocol_state.Body in
        let genesis_consensus_state = consensus_state genesis_state_body in
        let consensus_state_block =
          Consensus.Data.Consensus_state.Value.For_tests
          .with_global_slot_since_genesis genesis_consensus_state slot
        in
        For_tests.with_consensus_state genesis_state_body consensus_state_block
      in
      let ledger = create_ledger () in
      let slot1 = Mina_numbers.Global_slot.of_int 1 in
      let _parties0, account0 =
        let state_body = make_state_body slot1 in
        []
        |> Parties.Call_forest.cons_tree Add_sequence_events.party
        |> Parties.Call_forest.cons_tree Initialize_party.party
        |> Parties.Call_forest.cons Deploy_party.party
        |> test_parties ~state_body ~ledger
      in
      assert (Option.is_some account0) ;
      let seq_state_elts0, last_seq_slot0 =
        seq_state_elts_of_account account0
      in
      (* we changed the 0th sequence state element
         there's a shift, but because the 0th element
         was the default, all other elements remain
         the default
      *)
      List.iteri seq_state_elts0 ~f:(fun i elt ->
          if i = 0 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Sequence_events.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Sequence_events.empty_state_element ) ) ;
      (* seq slot is 1 *)
      assert (Mina_numbers.Global_slot.equal slot1 last_seq_slot0) ;
      let slot2 = Mina_numbers.Global_slot.of_int 2 in
      let _parties1, account1 =
        let state_body = make_state_body slot2 in
        []
        |> Parties.Call_forest.cons_tree Add_sequence_events.party
        |> test_parties ~state_body ~fee_payer_nonce:1 ~ledger
      in
      assert (Option.is_some account1) ;
      let seq_state_elts1, last_seq_slot1 =
        seq_state_elts_of_account account1
      in
      (* we changed the 0th sequence state element
         this time the shift also changes the 1st element
      *)
      List.iteri seq_state_elts1 ~f:(fun i elt ->
          if i >= 0 && i <= 1 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Sequence_events.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Sequence_events.empty_state_element ) ) ;
      (* check the shifted elements *)
      for i = 1 to 4 do
        let last_elt = List.nth_exn seq_state_elts0 (i - 1) in
        let curr_elt = List.nth_exn seq_state_elts1 i in
        assert (Impl.Field.Constant.equal last_elt curr_elt)
      done ;
      (* seq slot is 2 *)
      assert (Mina_numbers.Global_slot.equal slot2 last_seq_slot1) ;
      let slot3 = Mina_numbers.Global_slot.of_int 3 in
      let _parties2, account2 =
        let state_body = make_state_body slot3 in
        []
        |> Parties.Call_forest.cons_tree Add_sequence_events.party
        |> test_parties ~state_body ~fee_payer_nonce:2 ~ledger
      in
      assert (Option.is_some account2) ;
      let seq_state_elts2, last_seq_slot2 =
        seq_state_elts_of_account account2
      in
      (* we changed the 0th sequence state element
         the shift also has changed the 1st, 2nd elements
      *)
      List.iteri seq_state_elts2 ~f:(fun i elt ->
          if i >= 0 && i <= 2 then
            assert (
              not
              @@ Impl.Field.Constant.equal elt
                   Zkapp_account.Sequence_events.empty_state_element )
          else
            assert (
              Impl.Field.Constant.equal elt
                Zkapp_account.Sequence_events.empty_state_element ) ) ;
      (* check the shifted elements *)
      for i = 1 to 4 do
        let last_elt = List.nth_exn seq_state_elts1 (i - 1) in
        let curr_elt = List.nth_exn seq_state_elts2 i in
        assert (Impl.Field.Constant.equal last_elt curr_elt)
      done ;
      (* seq slot is 3 *)
      assert (Mina_numbers.Global_slot.equal slot3 last_seq_slot2)
  end )
