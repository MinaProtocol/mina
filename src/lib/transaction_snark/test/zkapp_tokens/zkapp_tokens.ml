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

    let token_accounts = Array.init 4 ~f:(fun _ -> Keypair.create ())

    let custom_token_id =
      Account_id.derive_token_id
        ~owner:
          (Account_id.create
             (Public_key.compress token_owner.public_key)
             Token_id.default )

    let custom_token_id2 =
      Account_id.derive_token_id
        ~owner:
          (Account_id.create
             (Public_key.compress token_owner.public_key)
             custom_token_id )

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
              let check_token_balance (keypair : Keypair.t) token_id balance =
                [%test_eq: Currency.Balance.t]
                  (ledger_get_exn ledger
                     (Public_key.compress keypair.public_key)
                     token_id )
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
                      ( [ fee_payer_keypair; token_owner; token_funder ]
                      @ Array.to_list token_accounts )
                      ~init:Public_key.Compressed.Map.empty
                      ~f:(fun map { private_key; public_key } ->
                        Public_key.Compressed.Map.add_exn map
                          ~key:(Public_key.compress public_key)
                          ~data:private_key )
                  in
                  let kp, _ = keypair_and_amounts.(0) in
                  let pk = Public_key.compress kp.public_key in
                  let nonce_from_ledger () =
                    let _, ({ nonce; _ } : Account.t), _ =
                      Mina_ledger.Ledger.Ledger_inner.get_or_create ledger
                        (Account_id.create pk Token_id.default)
                      |> Or_error.ok_exn
                    in
                    nonce
                  in
                  let%bind create_token_zkapp_command =
                    let open Zkapp_command_builder in
                    let nonce = nonce_from_ledger () in
                    let with_dummy_signatures =
                      mk_forest
                        [ mk_node
                            (mk_account_update_body Call token_funder
                               Token_id.default
                               (-(11 * account_creation_fee)) )
                            []
                        ; mk_node
                            (mk_account_update_body Call token_owner
                               Token_id.default
                               (10 * account_creation_fee) )
                            []
                        ]
                      |> mk_zkapp_command ~fee:7 ~fee_payer_pk:pk
                           ~fee_payer_nonce:nonce
                    in
                    replace_authorizations ~keymap with_dummy_signatures
                  in
                  let%bind () =
                    U.check_zkapp_command_with_merges_exn ledger
                      [ create_token_zkapp_command ]
                  in
                  ignore
                    ( ledger_get_exn ledger
                        (Public_key.compress token_owner.public_key)
                        Token_id.default
                      : Account.t ) ;
                  let%bind mint_token_zkapp_command =
                    let open Zkapp_command_builder in
                    let nonce = nonce_from_ledger () in
                    let with_dummy_signatures =
                      mk_forest
                        [ mk_node
                            (mk_account_update_body Call token_owner
                               Token_id.default (-account_creation_fee) )
                            [ mk_node
                                (mk_account_update_body Call token_accounts.(0)
                                   custom_token_id 100 )
                                []
                            ]
                        ]
                      |> mk_zkapp_command ~fee:7 ~fee_payer_pk:pk
                           ~fee_payer_nonce:nonce
                    in
                    replace_authorizations ~keymap with_dummy_signatures
                  in
                  let%bind () =
                    U.check_zkapp_command_with_merges_exn ledger
                      [ mint_token_zkapp_command ]
                  in
                  check_token_balance token_accounts.(0) custom_token_id 100 ;
                  let%bind mint_token2_zkapp_command =
                    let open Zkapp_command_builder in
                    let nonce = nonce_from_ledger () in
                    let with_dummy_signatures =
                      mk_forest
                        [ mk_node
                            (mk_account_update_body Call token_owner
                               Token_id.default
                               (-2 * account_creation_fee) )
                            [ mk_node
                                (mk_account_update_body Call token_owner
                                   custom_token_id 0 )
                                [ mk_node
                                    (mk_account_update_body Call
                                       token_accounts.(2) custom_token_id2 500 )
                                    []
                                ]
                            ]
                        ]
                      |> mk_zkapp_command ~fee:7 ~fee_payer_pk:pk
                           ~fee_payer_nonce:nonce
                    in
                    replace_authorizations ~keymap with_dummy_signatures
                  in
                  let%bind () =
                    U.check_zkapp_command_with_merges_exn ledger
                      [ mint_token2_zkapp_command ]
                  in
                  check_token_balance token_accounts.(2) custom_token_id2 500 ;
                  let%bind token_transfer_zkapp_command =
                    let open Zkapp_command_builder in
                    let nonce = nonce_from_ledger () in
                    let with_dummy_signatures =
                      mk_forest
                        [ mk_node
                            (mk_account_update_body Call token_owner
                               Token_id.default
                               (-2 * account_creation_fee) )
                            [ mk_node
                                (mk_account_update_body Call token_accounts.(0)
                                   custom_token_id (-30) )
                                []
                            ; mk_node
                                (mk_account_update_body Call token_accounts.(1)
                                   custom_token_id 30 )
                                []
                            ; mk_node
                                (mk_account_update_body Call fee_payer_keypair
                                   Token_id.default (-50) )
                                []
                            ; mk_node
                                (mk_account_update_body Call token_funder
                                   Token_id.default 50 )
                                []
                            ; mk_node
                                (mk_account_update_body Call token_accounts.(0)
                                   custom_token_id (-10) )
                                []
                            ; mk_node
                                (mk_account_update_body Call token_accounts.(1)
                                   custom_token_id 10 )
                                []
                            ; mk_node
                                (mk_account_update_body Call token_accounts.(1)
                                   custom_token_id (-5) )
                                []
                            ; mk_node
                                (mk_account_update_body Call token_accounts.(0)
                                   custom_token_id 5 )
                                []
                            ; mk_node
                                (mk_account_update_body Call token_owner
                                   custom_token_id 0 )
                                [ mk_node
                                    (mk_account_update_body Call
                                       token_accounts.(2) custom_token_id2 (-210) )
                                    []
                                ; mk_node
                                    (mk_account_update_body Call
                                       token_accounts.(3) custom_token_id2 210 )
                                    []
                                ]
                            ]
                        ]
                      |> mk_zkapp_command ~fee:7 ~fee_payer_pk:pk
                           ~fee_payer_nonce:nonce
                    in
                    replace_authorizations ~keymap with_dummy_signatures
                  in
                  let%bind () =
                    U.check_zkapp_command_with_merges_exn ledger
                      [ token_transfer_zkapp_command ]
                  in
                  check_token_balance token_accounts.(0) custom_token_id 65 ;
                  check_token_balance token_accounts.(1) custom_token_id 35 ;
                  check_token_balance token_accounts.(2) custom_token_id2 290 ;
                  check_token_balance token_accounts.(3) custom_token_id2 210 ;
                  Async.Deferred.unit ) ) )
  end )
