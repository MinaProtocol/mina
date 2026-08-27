module Z = Block_producer.Zero_coinbase_logging

let check_reason expected source ?(coinbase_amount = Some Currency.Amount.zero)
    ?(coinbase_parts = 0) () =
  let label = String.concat "," expected in
  Alcotest.(check (list string))
    label expected
    (Z.zero_reason ~coinbase_amount ~coinbase_parts
       { Z.supercharge_coinbase = false; source } )

let test_diagnostics ?(insufficient_work = 0) ?(insufficient_space = 0)
    ?(insufficient_fees = 0) ?(extra_work = 0) ?(start_commands = 0)
    ?(start_completed_work = 0) ?(end_commands = 0) ?(end_completed_work = 0)
    ?(end_coinbase_parts = 0) () =
  let open Staged_ledger.Diff_creation_diagnostics in
  { proof_count = 0
  ; valid_user_command_count = start_commands
  ; partitions =
      [ { partition = `First
        ; start_commands
        ; start_completed_work
        ; available_slots = 0
        ; required_work_count = 0
        ; end_commands
        ; end_completed_work
        ; end_coinbase_parts
        ; discard_counters =
            { insufficient_work
            ; insufficient_space
            ; insufficient_fees
            ; extra_work
            }
        }
      ]
  }

let test_explicit_slot_tx_end () =
  check_reason [ "slot_tx_end_reached" ]
    (Z.Slot_tx_end_reached Mina_numbers.Global_slot_since_hard_fork.zero) ()

let test_explicit_min_reward_threshold () =
  check_reason
    [ "below_min_block_reward" ]
    (Z.Below_min_block_reward
       { threshold = Currency.Amount.zero; reward = Currency.Amount.zero } )
    ()

let test_unavailable_amount () =
  check_reason
    [ "coinbase_amount_unavailable"; "empty_diff_no_resources" ]
    (Z.Generated_diff (test_diagnostics ()))
    ~coinbase_amount:None ~coinbase_parts:1 ()

let test_insufficient_work () =
  check_reason
    [ "empty_diff_no_resources"; "insufficient_work" ]
    (Z.Generated_diff (test_diagnostics ~insufficient_work:1 ()))
    ()

let test_insufficient_fees () =
  check_reason
    [ "empty_diff_no_resources"; "insufficient_fees" ]
    (Z.Generated_diff (test_diagnostics ~insufficient_fees:1 ()))
    ()

let test_insufficient_space () =
  check_reason
    [ "empty_diff_no_resources"; "insufficient_space" ]
    (Z.Generated_diff (test_diagnostics ~insufficient_space:1 ()))
    ()

let test_empty_resources () =
  check_reason
    [ "empty_diff_no_resources" ]
    (Z.Generated_diff (test_diagnostics ()))
    ()

let test_precomputed () =
  check_reason [ "precomputed_zero_coinbase" ] Z.Precomputed ()

let () =
  Alcotest.run "zero coinbase logging"
    [ ( "reason priority"
      , [ Alcotest.test_case "slot_tx_end" `Quick test_explicit_slot_tx_end
        ; Alcotest.test_case "min_block_reward" `Quick
            test_explicit_min_reward_threshold
        ; Alcotest.test_case "amount_unavailable" `Quick test_unavailable_amount
        ; Alcotest.test_case "insufficient_work" `Quick test_insufficient_work
        ; Alcotest.test_case "insufficient_fees" `Quick test_insufficient_fees
        ; Alcotest.test_case "insufficient_space" `Quick test_insufficient_space
        ; Alcotest.test_case "empty_resources" `Quick test_empty_resources
        ; Alcotest.test_case "precomputed" `Quick test_precomputed
        ] )
    ]
