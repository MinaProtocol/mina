open Alcotest

let () =
  run "account timing"
    [ ( "timing check"
      , [ test_case "before cliff time" `Quick
            Account_timing_tests.before_cliff_time
        ; test_case "positive min balance" `Quick
            Account_timing_tests.positive_min_balance
        ; test_case "curr min balance of zero" `Quick
            Account_timing_tests.curr_min_balance_of_zero
        ; test_case "below calculated min balance" `Quick
            Account_timing_tests.below_calculated_min_balance
        ; test_case "insufficient balance" `Quick
            Account_timing_tests.insufficient_balance
        ; test_case "past full vesting" `Quick
            Account_timing_tests.past_full_vesting
        ; test_case "before cliff, cliff_amount doesn't affect min balance"
            `Quick
            Account_timing_tests.before_cliff_amount_doesnt_affect_min_balance
        ; test_case "at exactly cliff time, cliff amount allows spending" `Quick
            Account_timing_tests.at_cliff_time_cliff_amount_allows_spending
        ] )
    ; ( "user commands"
      , [ test_case "before cliff time, sufficient balance" `Quick
            Account_timing_tests
            .user_commands_before_cliff_time_sufficient_balance
        ; test_case "before cliff time, min balance violation" `Quick
            Account_timing_tests
            .user_command_before_cliff_time_min_balance_violation
        ; test_case "just before cliff time, insufficient balance" `Quick
            Account_timing_tests
            .user_command_just_before_cliff_time_insufficient_balance
        ; test_case "at cliff time, sufficient balance" `Quick
            Account_timing_tests.user_command_at_cliff_time_sufficient_balance
        ; test_case "while vesting, sufficient balance" `Quick
            Account_timing_tests.user_command_while_vesting_sufficient_balance
        ; test_case "after vesting, sufficient balance" `Quick
            Account_timing_tests.user_command_after_vesting_sufficient_balance
        ; test_case "after vesting, insufficient balance" `Quick
            Account_timing_tests.user_command_after_vesting_insufficient_balance
        ; test_case "payment - fee more than available min balance" `Quick
            Account_timing_tests.payment_fee_more_than_available_min_balance
        ; test_case "payment - amount more than available min balance" `Quick
            Account_timing_tests.payment_amount_more_than_available_min_balance
        ; test_case
            "payment - fee payer goes from timed to untimed, receiver untimed"
            `Quick
            Account_timing_tests
            .payment_fee_payer_timed_to_untimed_receiver_untimed
        ; test_case
            "payment - receiver goes from timed to untimed, fee payer untimed"
            `Quick
            Account_timing_tests
            .payment_receiver_timed_to_untimed_fee_payer_untimed
        ; test_case "generic user transaction" `Quick
            Account_timing_tests.generic_user_transaction
        ] )
    ; ( "zkapp commands"
      , [ test_case "before cliff time, sufficient balance" `Quick
            Account_timing_tests
            .zkapp_command_before_cliff_time_sufficient_balance
        ; test_case "before cliff time, min balance violation" `Quick
            Account_timing_tests
            .zkapp_command_before_cliff_time_min_balance_violation
        ; test_case "before cliff time, fee payer fails" `Quick
            Account_timing_tests.zkapp_command_before_cliff_time_fee_payer_fails
        ; test_case "timed account creation, min_balance > balance" `Quick
            Account_timing_tests
            .zkapp_command_timed_account_creation_min_balance_gt_balance
        ; test_case "account creation, min_balance = balance" `Quick
            Account_timing_tests
            .zkapp_command_account_creation_min_balance_eq_balance
        ; test_case "account creation, min_balance < balance" `Quick
            Account_timing_tests
            .zkapp_command_account_creation_min_balance_lt_balance
        ; test_case "just before cliff time, insufficient balance" `Quick
            Account_timing_tests
            .zkapp_command_just_before_cliff_time_insufficient_balance
        ; test_case "at cliff time, sufficient balance" `Quick
            Account_timing_tests.zkapp_command_at_cliff_time_sufficient_balance
        ; test_case "while vesting, sufficient balance" `Quick
            Account_timing_tests.zkapp_command_while_vesting_sufficient_balance
        ; test_case "while vesting, insufficient balance" `Quick
            Account_timing_tests
            .zkapp_command_while_vesting_insufficient_balance
        ; test_case "after vesting, sufficient balance" `Quick
            Account_timing_tests.zkapp_command_after_vesting_sufficient_balance
        ; test_case "after vesting, insufficient balance" `Quick
            Account_timing_tests
            .zkapp_command_after_vesting_insufficient_balance
        ; test_case "create timed account with wrong authorization" `Quick
            Account_timing_tests
            .zkapp_command_create_timed_account_wrong_authorization
        ; test_case "change untimed account to timed" `Quick
            Account_timing_tests.zkapp_command_change_untimed_to_timed
        ; test_case "invalid update for timed account" `Quick
            Account_timing_tests.zkapp_command_invalid_update_for_timed_account
        ] )
    ]
