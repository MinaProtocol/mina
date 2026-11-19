let () =
  let open Alcotest in
  run "Block producer"
    [ ( "select_staged_ledger_diff"
      , Select_staged_ledger_diff_test.
          [ test_case "Warming up leaves snark work to buy" `Quick
              warm_up_leaves_work_to_buy
          ; test_case "A coinbase-only block pays for snark work" `Quick
              coinbase_pays_for_snark_work
          ; test_case
              "Optional snark work can empty a block that would otherwise meet \
               the threshold"
              `Quick optional_snark_work_can_empty_a_block
          ; test_case "Transaction fees pay for expensive then cheap snark work"
              `Quick transaction_fees_pay_for_expensive_then_cheap_work
          ; test_case "Snark work the coinbase cannot pay for is left out"
              `Quick unaffordable_snark_work_is_left_out
          ; test_case "Blocks after slot_tx_end are empty" `Quick
              slot_tx_end_empties_the_block
          ] )
    ]
