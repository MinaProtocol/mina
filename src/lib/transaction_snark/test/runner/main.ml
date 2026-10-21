let () =
  Alcotest.run "Transaction snark"
    [ Transaction_snark_tests_access_permission
      .Transaction_snark_test_access_permission
      .suite ()
    ; Account_update_network_id.suite ()
    ; App_state_tests.App_state.suite ()
    ; Delegate_tests.Delegate.suite ()
    ; Fee_payer_tests.Fee_payer.suite ()
    ; Multisig_tests.Multisig_account.suite ()
    ; Permissions_tests.Permissions.suite ()
    ; Token_symbol_tests.Token_symbol.suite ()
    ; Verification_key_tests.Verification_key.suite ()
    ; Verification_key_permission_tests.Verification_key_permission.suite ()
    ; Voting_for_tests.Voting_for.suite ()
    ; Zkapp_deploy_tests.Zkapp_deploy.suite ()
    ; Zkapp_uri_tests.Zkapp_uri.suite ()
    ]
