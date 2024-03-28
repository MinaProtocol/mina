open Alcotest

let () =
  run "Test staged ledger."
    [ Txn_application_test.
        ( "txn application"
        , [ test_case
              "Any txn can be applied if there's space in the scan state."
              `Quick apply_against_non_empty_scan_state
          ] )
    ]
