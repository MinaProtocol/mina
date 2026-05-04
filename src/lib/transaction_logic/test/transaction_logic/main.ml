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
    ; Stake_change.
        ( "stake_change"
        , [ test_case "Payment success, neither staked" `Quick
              payment_success_neither_staked
          ; test_case "Payment success, both staked" `Quick
              payment_success_both_staked
          ; test_case "Payment success, sender staked only" `Quick
              payment_success_sender_staked_only
          ; test_case "Payment success, receiver staked only" `Quick
              payment_success_receiver_staked_only
          ; test_case
              "Payment fail (receiver receive=Impossible), sender staked" `Quick
              payment_fail_sender_staked
          ; test_case
              "Payment fail (receiver receive=Impossible), sender unstaked"
              `Quick payment_fail_sender_unstaked
          ; test_case "Delegation Some→Some" `Quick delegation_some_to_some
          ; test_case "Delegation Some→None (opt-out)" `Quick
              delegation_some_to_none
          ; test_case "Delegation None→Some (opt-in)" `Quick
              delegation_none_to_some
          ; test_case "Delegation None→None" `Quick delegation_none_to_none
          ; test_case "Delegation failed (unknown receiver), sender staked"
              `Quick delegation_failed_sender_staked
          ; test_case "Delegation failed (unknown receiver), sender unstaked"
              `Quick delegation_failed_sender_unstaked
          ; test_case
              "Delegation not permitted (set_delegate=Proof), sender staked"
              `Quick delegation_not_permitted_sender_staked
          ; test_case
              "Delegation not permitted (set_delegate=Proof), sender unstaked"
              `Quick delegation_not_permitted_sender_unstaked
          ; test_case "Fee_transfer one single (staked)" `Quick
              fee_transfer_one_staked
          ; test_case "Fee_transfer one single (unstaked)" `Quick
              fee_transfer_one_unstaked
          ; test_case "Fee_transfer one single (receive rejected)" `Quick
              fee_transfer_one_rejected
          ; test_case "Fee_transfer two singles (only pk1 staked)" `Quick
              fee_transfer_two_mixed
          ; test_case "Fee_transfer two singles (fp slot rejected)" `Quick
              fee_transfer_two_fp_rejected
          ; test_case "Fee_transfer two singles (rcv slot rejected)" `Quick
              fee_transfer_two_rcv_rejected
          ; test_case "Fee_transfer two singles (both rejected)" `Quick
              fee_transfer_two_both_rejected
          ; test_case "Coinbase no fee_transfer (staked)" `Quick
              coinbase_no_ft_staked
          ; test_case "Coinbase no fee_transfer (unstaked)" `Quick
              coinbase_no_ft_unstaked
          ; test_case "Coinbase no fee_transfer (receive rejected)" `Quick
              coinbase_no_ft_rejected
          ; test_case "Coinbase with fee_transfer (only cb receiver staked)"
              `Quick coinbase_with_ft_mixed
          ; test_case "Coinbase with fee_transfer (sw rejected)" `Quick
              coinbase_with_ft_sw_rejected
          ; test_case "Coinbase with fee_transfer (bp rejected)" `Quick
              coinbase_with_ft_bp_rejected
          ; test_case "Coinbase with fee_transfer (both rejected)" `Quick
              coinbase_with_ft_both_rejected
          ] )
    ]
