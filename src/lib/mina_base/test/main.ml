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
    ; Account_update_test.
      ( "account updates"
      , [ test_case "Update JSON roundtrip" `Quick update_json_roundtrip 
        ; test_case "Precondition JSON roundtrip accept" `Quick
            precondition_json_roundtrip_accept 
        ; test_case "Precondition JSON roundtrip nonce" `Quick
            precondition_json_roundtrip_nonce 
        ; test_case "Precondition JSON roundtrip with full nonce" `Quick
            precondition_json_roundtrip_full_with_nonce 
        ; test_case "Precondition JSON roundtrip full" `Quick
            precondition_json_roundtrip_full 
        ; test_case "Precondition to JSON" `Quick precondition_to_json 
        ; test_case "Body fee payer JSON roundtrip" `Quick
            body_fee_payer_json_roundtrip 
        ; test_case "Body JSON roundtrip" `Quick body_json_roundtrip 
        ; test_case "Fee payer JSON roundtrip" `Quick fee_payer_json_roundtrip 
        ; test_case "JSON roundtrip dummy" `Quick json_roundtrip_dummy
      ])
    ; Call_forest_test.
        ( "call forest"
        , [ test_case "Test fold_forest." `Quick Tree_test.fold_forest
          ; test_case "Test fold_forest2." `Quick Tree_test.fold_forest2
          ; test_case "Test fold_forest2 failure." `Quick
              Tree_test.fold_forest2_fails
          ; test_case "Test iter_forest2_exn." `Quick Tree_test.iter_forest2_exn
          ; test_case "Test iter_forest2_exn failure." `Quick
              Tree_test.iter_forest2_exn_fails
          ; test_case "iter2_exn" `Quick Tree_test.iter2_exn
          ; test_case "mapi with trees preserves shape." `Quick
              Tree_test.mapi_with_trees_preserves_shape
          ; test_case "mapi with trees preserves shape." `Quick
              Tree_test.mapi_with_trees_unit_test
          ; test_case "Test mapi with trees." `Quick
              Tree_test.mapi_forest_with_trees_preserves_shape
          ; test_case "mapi_forest with trees preserves shape." `Quick
              Tree_test.mapi_forest_with_trees_unit_test
          ; test_case "Test mapi_forest with trees." `Quick
              Tree_test.mapi_forest_with_trees_is_distributive
          ; test_case "mapi_forest with trees is distributive." `Quick
              Tree_test.mapi_prime_preserves_shape
          ; test_case "mapi' preserves shape." `Quick
              Tree_test.mapi_prime_preserves_shape
          ; test_case "Test mapi'." `Quick Tree_test.mapi_prime
          ; test_case "Test mapi_forest'." `Quick Tree_test.mapi_forest_prime
          ; test_case "map_forest is distibutive." `Quick
              Tree_test.map_forest_is_distributive
          ; test_case "deferred_map_forest is equivalent to map_forest." `Quick
              Tree_test.deferred_map_forest_equivalent_to_map_forest
          ; test_case "Test shape." `Quick test_shape
          ; test_case "shape_indices always start with 0 and increse by 1."
              `Quick shape_indices_always_start_with_0_and_increse_by_1
          ; test_case "Test match_up success." `Quick match_up_ok
          ; test_case "Test match_up failure." `Quick match_up_error
          ; test_case "Test match_up failure 2." `Quick match_up_error_2
          ; test_case "Test match_up empty." `Quick match_up_empty
          ; test_case "Test mask." `Quick mask
          ; test_case "to_account_updates is the inverse of of_account_updates."
              `Quick to_account_updates_is_the_inverse_of_of_account_updates
          ; test_case "Test to_zkapp_command with hashes list." `Quick
              to_zkapp_command_with_hashes_list
          ] )
    ; Fee_related_test.
        ( "fee-related"
        , [ test_case "Test fee." `Quick test_fee
          ; test_case "Test fee_payer account update." `Quick
              fee_payer_account_update
          ; test_case "Test fee_payer public key." `Quick fee_payer_pk
          ; test_case "Test fee_excess." `Quick fee_excess
          ] )
    ; Merkle_tree_test.
        ( "merkle tree"
        , [ test_case "Test isomorphism between lists and merkle trees." `Quick
              merkle_tree_isomorphic_to_list
          ; test_case "Test item retrieval by index." `Quick index_retrieval
          ; test_case "Test non-existent index retrieval." `Quick
              index_non_existent
          ; test_case "Test merkle root soundness." `Quick merkle_root
        ] )
    ; Receipt_test.
      ( "receipts"
      , [ test_case "Checked-unmchecked equivalence for signed command" `Quick
            checked_unchecked_equivalence_signed_command 
        ; test_case "Checked-unchecked equivalenece in zkApp command" `Quick
            checked_unchecked_equivalence_zkapp_command 
        ; test_case "JSON roundtrip" `Quick json_roundtrip 
      ])
    ; Signature_test.
      ( "signatures"
      , [ test_case "Signature decode after encode i identity" `Quick
            signature_decode_after_encode_is_identity 
        ; test_case "Base58check is stable" `Quick base58Check_stable 
      ])
    ]
