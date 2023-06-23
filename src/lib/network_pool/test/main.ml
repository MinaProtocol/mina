open Alcotest

let () =
  run "Test the network pool."
    [ Indexed_pool_tests.
        ( "indexed pool"
        , [ test_case "Test invariants hold on empty data structure" `Quick
              empty_invariants
          ; test_case "Test properties of a singleton pool" `Quick
              singleton_properties
          ; test_case "Test a sequence of valid additions" `Quick
              sequential_adds_all_valid
          ; test_case "Test replacement" `Quick replacement
          ; test_case "Txn with lowest fee rate is removed" `Quick
              remove_lowest_fee
          ; test_case "For application pick the txn with the highest fee rate"
              `Quick pick_highest_fee_for_application
          ; test_case "Test support for zkApp commands." `Quick
              support_for_zkapp_command_commands
          ; test_case
              "Transactions from single source should be ordered by nonce"
              `Quick transactions_from_single_sender_ordered_by_nonce
          ; test_case
              "Transactions for application should not contain nonce gaps"
              `Quick transactions_from_many_senders_no_nonce_gaps
          ; test_case
              "Nonce increment side effects from other zkapp_command are \
               handled properly"
              `Quick nonce_increment_side_effects
          ; test_case
              "Nonce invariant violations on committed transactions does not \
               trigger a crash "
              `Quick nonce_invariant_violation
          ; test_case "Revalidation drops nothing unsless ledger changed" `Quick
              revalidation_drops_nothing_unless_ledger_changed
          ; test_case "Applying transactions invalidates them" `Quick
              application_invalidates_applied_transactions
          ] )
    ]
