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
          ; test_case "Transaction can be replaced by one with higher fee"
              `Quick transaction_replacement
          ; test_case
              "After a replacement, later transactions are discarded, if  \
               account's balance can't support them anymore"
              `Quick transaction_replacement_insufficient_balance
          ] )
    ; Transaction_pool_tests.
        ( "transaction pool"
        , [ test_case "Transactions are removed in linear case (user cmds)"
              `Quick transactions_are_removed_in_linear_case_zkapps
          ; test_case "Transactions are removed in linear case (zkapps)" `Quick
              transactions_are_removed_in_linear_case_zkapps
          ; test_case
              "Transactions are removed and added back in fork changes (user \
               cmds)"
              `Quick
              transactions_are_removed_and_added_back_in_fork_changes_user_cmds
          ; test_case
              "Transactions are removed and added back in fork changes (zkapps)"
              `Quick
              transactions_are_removed_and_added_back_in_fork_changes_zkapps
          ; test_case "Invalid transactions are not accepted (user cmds)" `Quick
              invalid_transactions_are_not_accepted_user_cmds
          ; test_case "Invalid transactions are not accepted (zkapps)" `Quick
              invalid_transactions_are_not_accepted_zkapps
          ; test_case
              "Now-invalid transactions are removed from the pool on fork \
               changes (user cmds)"
              `Quick
              now_invalid_transactions_are_removed_from_pool_on_fork_changes_user_cmds
          ; test_case
              "Now-invalid transactions are removed from the pool on fork \
               changes (zkapps)"
              `Quick
              now_invalid_transactions_are_removed_from_pool_on_fork_changes_zkapps
          ; test_case "Expired transactions are not accepted (user cmds)" `Quick
              expired_transactions_are_not_accepted_user_cmds
          ; test_case "Expired transactions are not accepted (zkapps)" `Quick
              expired_transactions_are_not_accepted_zkapps
          ; test_case
              "Expired transactions that are already in the pool are removed \
               from the pool when best tip changes (user commands)"
              `Quick
              expired_transactions_that_are_already_in_pool_are_removed_from_pool_on_best_tip_change_uc
          ; test_case
              "Expired transactions that are already in the pool are removed \
               from the pool when best tip changes (zkapps)"
              `Quick
              expired_transactions_that_are_already_in_pool_are_removed_from_pool_on_best_tip_change_zkapp
          ; test_case
              "Now-invalid transactions are removed from the pool when the \
               transition frontier is recreated (user cmds)"
              `Quick
              now_invalid_transactions_are_removed_from_the_pool_when_the_transition_frontier_is_recreated_uc
          ; test_case "transaction replacement works" `Quick
              transaction_replacement_works
          ; test_case
              "it drops queued transactions if a committed one makes there be \
               insufficient funds"
              `Quick
              it_drops_queued_transactions_if_a_committed_one_makes_there_be_insufficient_funds
          ; test_case "max size is maintained" `Quick max_size_is_maintained
          ; test_case "rebroadcastable transaction behavior (user cmds)" `Quick
              rebroadcastable_transaction_behavior_user_cmds
          ; test_case "rebroadcastable transaction behavior (zkapps)" `Quick
              rebroadcastable_transaction_behavior_zkapps
          ; test_case "apply user cmds and zkapps" `Quick
              apply_user_cmds_and_zkapps
          ; test_case
              "zkapp cmd with same nonce should replace previous submitted \
               zkapp with same nonce"
              `Quick
              zkapp_cmd_with_same_nonce_should_replace_previous_submitted_zkapp_with_same_nonce
          ; test_case
              "commands are rejected if fee payer permissions are not handled"
              `Quick
              commands_are_rejected_if_fee_payer_permissions_are_not_handled
          ; test_case
              "account update with a different network id that uses proof \
               authorization would be rejected"
              `Quick
              account_update_with_a_different_network_id_that_uses_proof_authorization_would_be_rejected
          ; test_case "transactions added before slot_tx_end are accepted"
              `Quick transactions_added_before_slot_tx_end_are_accepted
          ; test_case "transactions added at slot_tx_end are rejected" `Quick
              transactions_added_at_slot_tx_end_are_rejected
          ; test_case "transactions added after slot_tx_end are rejected" `Quick
              transactions_added_after_slot_tx_end_are_rejected
          ; test_case "transactions are removed in linear case (user cmds)"
              `Quick transactions_are_removed_in_linear_case_user_cmds
          ; test_case "transactions are removed in linear case (zkapps)" `Quick
              transactions_are_removed_in_linear_case_zkapps
          ] )
    ]
