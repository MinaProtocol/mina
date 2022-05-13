open Core_kernel
open Mina_ledger
open Signature_lib
open Mina_base
module Spec = Transaction_snark.For_tests.Spec
module Init_ledger = Mina_transaction_logic.For_tests.Init_ledger
module U = Transaction_snark_tests.Util

let%test_module "Zkapp tokens tests" =
  ( module struct
    (* code patterned after "tokens test" unit test in Mina_ledger.Ledger *)

    let constraint_constants = U.constraint_constants

    let account_creation_fee =
      Currency.Fee.to_int constraint_constants.account_creation_fee

    let keypair_and_amounts = Quickcheck.random_value (Init_ledger.gen ())

    let fee_payer_keypair, _ = keypair_and_amounts.(0)

    let token_funder, _ = keypair_and_amounts.(1)

    let token_owner = Keypair.create ()

    let token_account1 = Keypair.create ()

    let token_account2 = Keypair.create ()

    let custom_token_id =
      Account_id.derive_token_id
        ~owner:
          (Account_id.create
             (Public_key.compress token_owner.public_key)
             Token_id.default )

    let forest ps : (Party.Body.Wire.t, unit, unit) Parties.Call_forest.t =
      List.map ps ~f:(fun p -> { With_stack_hash.elt = p; stack_hash = () })

    let node party calls =
      { Parties.Call_forest.Tree.party
      ; party_digest = ()
      ; calls = forest calls
      }

    let mk_party_body caller kp token_id balance_change : Party.Body.Wire.t =
      { update = Party.Update.noop
      ; public_key = Public_key.compress kp.Keypair.public_key
      ; token_id
      ; balance_change =
          Currency.Amount.Signed.create
            ~magnitude:(Currency.Amount.of_int (Int.abs balance_change))
            ~sgn:(if Int.is_negative balance_change then Sgn.Neg else Pos)
      ; increment_nonce = false
      ; events = []
      ; sequence_events = []
      ; call_data = Pickles.Impls.Step.Field.Constant.zero
      ; call_depth = 0
      ; protocol_state_precondition = Zkapp_precondition.Protocol_state.accept
      ; use_full_commitment = true
      ; account_precondition = Accept
      ; caller
      }

    let mk_parties_transaction ledger other_parties : Parties.t =
      let fee_payer : Party.Fee_payer.t =
        let pk = Public_key.compress fee_payer_keypair.public_key in
        let _, ({ nonce; _ } : Account.t), _ =
          Ledger.Ledger_inner.get_or_create ledger
            (Account_id.create pk Token_id.default)
          |> Or_error.ok_exn
        in
        { body =
            { update = Party.Update.noop
            ; public_key = pk
            ; fee = Currency.Fee.of_int 7
            ; events = []
            ; sequence_events = []
            ; protocol_state_precondition =
                Zkapp_precondition.Protocol_state.accept
            ; nonce
            }
        ; authorization = Signature.dummy
        }
      in
      { fee_payer
      ; memo = Signed_command_memo.dummy
      ; other_parties =
          other_parties
          |> Parties.Call_forest.map
               ~f:(fun (p : Party.Body.Wire.t) : Party.Wire.t ->
                 { body = p; authorization = Signature Signature.dummy } )
          |> Parties.Call_forest.add_callers'
          |> Parties.Call_forest.accumulate_hashes_predicated
      }

    let ledger_get_exn ledger pk token =
      match
        Ledger.Ledger_inner.get_or_create ledger (Account_id.create pk token)
        |> Or_error.ok_exn
      with
      | `Added, _, _ ->
          failwith "Account did not exist"
      | `Existed, acct, _ ->
          acct

    let%test_unit "token operations" =
      Test_util.with_randomness 987654321 (fun () ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              let check_token_balance (keypair : Keypair.t) balance =
                [%test_eq: Currency.Balance.t]
                  (ledger_get_exn ledger
                     (Public_key.compress keypair.public_key)
                     custom_token_id )
                    .balance
                  (Currency.Balance.of_int balance)
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let open Async.Deferred.Let_syntax in
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    [| keypair_and_amounts.(0); keypair_and_amounts.(1) |]
                    ledger ;
                  let keymap =
                    List.fold
                      [ fee_payer_keypair
                      ; token_owner
                      ; token_funder
                      ; token_account1
                      ; token_account2
                      ] ~init:Public_key.Compressed.Map.empty
                      ~f:(fun map { private_key; public_key } ->
                        Public_key.Compressed.Map.add_exn map
                          ~key:(Public_key.compress public_key)
                          ~data:private_key )
                  in
                  let create_token_parties =
                    let with_dummy_signatures =
                      forest
                        [ node
                            (mk_party_body Call token_funder Token_id.default
                               (-(4 * account_creation_fee)) )
                            []
                        ; node
                            (mk_party_body Call token_owner Token_id.default
                               (3 * account_creation_fee) )
                            []
                        ]
                      |> mk_parties_transaction ledger
                    in
                    Parties.For_tests.replace_signatures ~keymap
                      with_dummy_signatures
                  in
                  let%bind () =
                    U.check_parties_with_merges_exn ledger
                      [ create_token_parties ]
                  in
                  ignore
                    ( ledger_get_exn ledger
                        (Public_key.compress token_owner.public_key)
                        Token_id.default
                      : Account.t ) ;
                  let mint_token_parties =
                    let with_dummy_signatures =
                      forest
                        [ node
                            (mk_party_body Call token_owner Token_id.default
                               (-account_creation_fee) )
                            [ node
                                (mk_party_body Call token_account1
                                   custom_token_id 100 )
                                []
                            ]
                        ]
                      |> mk_parties_transaction ledger
                    in
                    Parties.For_tests.replace_signatures ~keymap
                      with_dummy_signatures
                  in
                  let%bind () =
                    U.check_parties_with_merges_exn ledger
                      [ mint_token_parties ]
                  in
                  check_token_balance token_account1 100 ;
                  let token_transfer_parties =
                    let with_dummy_signatures =
                      forest
                        [ node
                            (mk_party_body Call token_owner Token_id.default
                               (-account_creation_fee) )
                            [ node
                                (mk_party_body Call token_account1
                                   custom_token_id (-30) )
                                []
                            ; node
                                (mk_party_body Call token_account2
                                   custom_token_id 30 )
                                []
                            ]
                        ]
                      |> mk_parties_transaction ledger
                    in
                    Parties.For_tests.replace_signatures ~keymap
                      with_dummy_signatures
                  in
                  let%bind () =
                    U.check_parties_with_merges_exn ledger
                      [ token_transfer_parties ]
                  in
                  check_token_balance token_account1 70 ;
                  check_token_balance token_account2 30 ;
                  Async.Deferred.unit ) ) )
  end )
