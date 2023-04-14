open Alcotest
open Mina_base

let () =
  run "Test mina_base."
    [ Zkapp_account_test.
        ( "zkapp-accounts"
        , [ test_case "Events pop after push is idempotent." `Quick
              (checked_pop_reverses_push (module Zkapp_account.Events))
          ; test_case "Actions pop after push is idempotent." `Quick
              (checked_pop_reverses_push (module Zkapp_account.Actions))
          ] )
    ; Account_test.
        ( "accounts"
        , [ test_case "Test fine-tuning of the account generation." `Quick
              fine_tuning_of_the_account_generation
          ; test_case "Cliff amount is immediately released at cliff time."
              `Quick cliff_amount_is_immediately_released_at_cliff_time
          ; test_case
              "Final vesting slot is the first when minimum balance is 0."
              `Quick final_vesting_slot_is_the_first_when_minimum_balance_is_0
          ; test_case "Minimum balance never changes before the cliff time."
              `Quick minimum_balance_never_changes_before_the_cliff_time
          ; test_case "Minimum balance never increases over time." `Quick
              minimum_balance_never_increases_over_time
          ; test_case
              "Every vesting period minimum balance decreases by vesting \
               increment."
              `Quick
              every_vesting_period_minimum_balance_decreases_by_vesting_increment
          ; test_case "Incremental balance between slots before cliff is 0."
              `Quick incremental_balance_between_slots_before_cliff_is_0
          ; test_case
              "Incremental balance between slots after vesting finished is 0."
              `Quick
              incremental_balance_between_slots_after_vesting_finished_is_0
          ; test_case "Incremental balance where end is before start is 0."
              `Quick incremental_balance_where_end_is_before_start_is_0
          ; test_case
              "Incremental balance during vesting is a multiple of vesting \
               increment."
              `Quick
              incremental_balance_during_vesting_is_a_multiple_of_vesting_increment
          ; test_case "Liquid balance in untimed account always equals balance."
              `Quick liquid_balance_in_untimed_account_equals_balance
          ; test_case
              "Liquid balance is balance - minimum balance at given slot."
              `Quick
              liquid_balance_is_balance_minus_minimum_balance_at_given_slot
          ; test_case "Token symbol to_bits of_bits roundtrip." `Quick
              token_symbol_to_bits_of_bits_roundtrip
          ; test_case "Token symbol of_bits to_bits roundtrip." `Quick
              token_symbol_of_bits_to_bits_roundtrip
          ] )
    ]
