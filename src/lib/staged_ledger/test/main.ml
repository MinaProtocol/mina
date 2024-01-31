open Alcotest

let () =
  run "Test staged ledger."
    [ ( "txn application"
      , [ test_case "Any txn can be applied if there's space in the scan state."
            `Quick Txn_application_test.apply_against_non_empty_scan_state
        ; test_case
            "A regular payment can be applied even when the ZkApp Limit has \
             been reached."
            `Quick Txn_application_test.zkapp_space_is_zero
        ] )
    ]
