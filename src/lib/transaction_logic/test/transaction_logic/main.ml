open Alcotest

let () =
  run "transaction logic"
    [ Transaction_logic.
        ( "transaction logic"
        , [ test_case "Simple funds transfer" `Quick simple_payment
          ; test_case "Fee payer cannot be different than sender" `Quick
              simple_payment_signer_different_from_fee_payer
          ; test_case
              "Coinbase transaction creates accounts in the correct order (no \
               fee transfer)"
              `Quick
              (coinbase_order_of_created_accounts_is_correct
                 ~with_fee_transfer:false )
          ; test_case
              "Coinbase transaction creates accounts in the correct order \
               (with fee transfer)"
              `Quick
              (coinbase_order_of_created_accounts_is_correct
                 ~with_fee_transfer:true )
          ] )
    ; Unstaking.
        ( "unstaking"
        , [ test_case "Opt-in from default unstaked state" `Quick
              opt_in_from_default_unstaked
          ; test_case "Opt-out via delegation to empty" `Quick
              opt_out_via_empty_delegation
          ; test_case "Opt-out from legacy self-delegated account" `Quick
              opt_out_from_legacy_self_delegated
          ; test_case "Delegating to unknown pk fails" `Quick
              delegating_to_unknown_pk_fails
          ] )
    ]
