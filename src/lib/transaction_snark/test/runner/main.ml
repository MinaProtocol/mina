let () =
  Alcotest.run "Transaction snark"
    [ App_state_tests.App_state.suite ()
    ; Delegate_tests.Delegate.suite ()
    ; Fee_payer_tests.Fee_payer.suite ()
    ; Permissions_tests.Permissions.suite ()
    ; Token_symbol_tests.Token_symbol.suite ()
    ; Verification_key_tests.Verification_key.suite ()
    ; Verification_key_permission_tests.Verification_key_permission.suite ()
    ; Voting_for_tests.Voting_for.suite ()
    ; Zkapp_uri_tests.Zkapp_uri.suite ()
    ]
