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

    let ( tag
        , _
        , p_module
        , Pickles.Provers.[ initialize_prover; update_state_prover; _ ] ) =
      Pickles.compile ~cache:Cache_dir.cache
        (module Zkapp_statement.Checked)
        (module Zkapp_statement)
        ~typ:Zkapp_statement.typ
        ~branches:(module Nat.N3)
        ~max_branching:(module Nat.N2) (* You have to put 2 here... *)
        ~name:"empty_update"
        ~constraint_constants:
          (Genesis_constants.Constraint_constants.to_snark_keys_header
             constraint_constants)
        ~choices:(fun ~self ->
          [ Zkapps_initialize_state.initialize_rule pk_compressed
          ; Zkapps_initialize_state.update_state_rule pk_compressed
          ; dummy_rule self
          ])

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
        ; account_precondition = Accept
        }

      let party : Party.t =
        (* TODO: This is a pain. *)
        { body = party_body; authorization = Signature Signature.dummy }
    end

    module Initialize_party = struct
      let party_body =
        Zkapps_initialize_state.generate_initialize_party pk_compressed

      let party_proof =
        Async.Thread_safe.block_on_async_exn (fun () ->
            initialize_prover []
              { transaction = Party.Body.digest party_body
              ; at_party = Parties.Call_forest.empty
              })

      let party : Party.t =
        { body = party_body; authorization = Proof party_proof }
    end

    module Update_state_party = struct
      let new_state = List.init 8 ~f:(fun _ -> Snark_params.Tick.Field.one)

      let party_body =
        Zkapps_initialize_state.generate_update_state_party pk_compressed
          new_state

      let party_proof =
        Async.Thread_safe.block_on_async_exn (fun () ->
            update_state_prover
              ~handler:(Zkapps_initialize_state.update_state_handler new_state)
              []
              { transaction = Party.Body.digest party_body
              ; at_party = Parties.Call_forest.empty
              })

      let party : Party.t =
        { body = party_body; authorization = Proof party_proof }
    end

    let protocol_state_precondition = Zkapp_precondition.Protocol_state.accept

    let test_parties parties =
      let ps =
        (* TODO: This is a pain. *)
        Parties.Call_forest.of_parties_list
          ~party_depth:(fun (p : Party.t) -> p.body.call_depth)
          parties
        |> Parties.Call_forest.accumulate_hashes_predicated
      in
      let memo = Signed_command_memo.empty in
      let transaction_commitment : Parties.Transaction_commitment.t =
        (* TODO: This is a pain. *)
        let other_parties_hash = Parties.Call_forest.hash ps in
        let protocol_state_predicate_hash =
          Zkapp_precondition.Protocol_state.digest protocol_state_precondition
        in
        let memo_hash = Signed_command_memo.hash memo in
        Parties.Transaction_commitment.create ~other_parties_hash
          ~protocol_state_predicate_hash ~memo_hash
      in
      let fee_payer_body =
        { Party.Body.Fee_payer.dummy with
          public_key = pk_compressed
        ; balance_change = Currency.Fee.(of_int 100)
        ; protocol_state_precondition
        }
      in
      let full_commitment =
        Parties.Transaction_commitment.with_fee_payer transaction_commitment
          ~fee_payer_hash:
            (Party.Body.digest (Party.Body.of_fee_payer fee_payer_body))
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
          List.map other_parties ~f:(function
            | { body = { public_key; use_full_commitment; _ }
              ; authorization = Signature _
              } as party
              when Public_key.Compressed.equal public_key pk_compressed ->
                let commitment =
                  if use_full_commitment then full_commitment
                  else transaction_commitment
                in
                { party with
                  authorization =
                    Signature
                      (Schnorr.Chunked.sign sk
                         (Random_oracle.Input.Chunked.field commitment))
                }
            | party ->
                party)
        in
        { fee_payer; other_parties; memo }
      in
      let parties : Parties.t =
        sign_all
          { fee_payer =
              { body = fee_payer_body; authorization = Signature.dummy }
          ; other_parties = parties
          ; memo
          }
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
          let () = apply_parties ledger [ parties ] in
          Ledger.get ledger loc |> Option.value_exn)

    let%test_unit "Initialize" =
      let account =
        test_parties [ Deploy_party.party; Initialize_party.party ]
      in
      let zkapp_state = (Option.value_exn account.zkapp).app_state in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state

    let%test_unit "Initialize and update" =
      let account =
        test_parties
          [ Deploy_party.party
          ; Initialize_party.party
          ; Update_state_party.party
          ]
      in
      let zkapp_state = (Option.value_exn account.zkapp).app_state in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal one) x))
        zkapp_state

    let%test_unit "Initialize and multiple update" =
      let account =
        test_parties
          [ Deploy_party.party
          ; Initialize_party.party
          ; Update_state_party.party
          ; Update_state_party.party
          ]
      in
      let zkapp_state = (Option.value_exn account.zkapp).app_state in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal one) x))
        zkapp_state

    let%test_unit "Update without initialize fails" =
      let account =
        test_parties [ Deploy_party.party; Update_state_party.party ]
      in
      assert (Option.is_none account.zkapp)

    let%test_unit "Double initialize fails" =
      let account =
        test_parties
          [ Deploy_party.party; Initialize_party.party; Initialize_party.party ]
      in
      assert (Option.is_none account.zkapp)

    let%test_unit "Initialize after update fails" =
      let account =
        test_parties
          [ Deploy_party.party
          ; Initialize_party.party
          ; Update_state_party.party
          ; Initialize_party.party
          ]
      in
      assert (Option.is_none account.zkapp)
  end )
