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
          ; test_case "Get txn with the hioghest fee rate" `Quick
              find_highest_fee
          ; test_case "Test support for zkApp commands." `Quick
              support_for_zkapp_command_commands
          ; test_case
              "Nonce increment side effects from other zkapp_command are \
               handled properly"
              `Quick nonce_increment_side_effects
          ; test_case
              "Nonce invariant violations on committed transactions does not \
               trigger a crash "
              `Quick nonce_invariant_violation
          ] )
    ]
