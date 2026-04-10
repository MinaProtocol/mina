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
          ; test_case "Payments between unstaked accounts" `Quick
              payments_with_unstaked_accounts
          ; test_case "stake_change: unstaked payment = 0" `Quick
              stake_change_unstaked_payment
          ; test_case "stake_change: staked payment = -fee" `Quick
              stake_change_staked_payment
          ; test_case "stake_change: opt-out = -balance" `Quick
              stake_change_opt_out
          ; test_case "stake_change: opt-in = +(balance - fee)" `Quick
              stake_change_opt_in
          ; test_case "zkapp stake_change: unstaked payment = 0" `Quick
              zkapp_stake_change_unstaked
          ; test_case "zkapp stake_change: staked fee_payer = -(fee+amount)"
              `Quick zkapp_stake_change_staked_fee_payer
          ; test_case "zkapp stake_change: delegate opt-in = +post_balance"
              `Quick zkapp_stake_change_delegate_opt_in
          ; test_case "zkapp stake_change: delegate opt-out = -pre_balance"
              `Quick zkapp_stake_change_delegate_opt_out
          ; test_case "zkapp stake_change: redelegate = -fee" `Quick
              zkapp_stake_change_redelegate
          ; test_case "stake_change: payment staked→unstaked = -(fee+amt)"
              `Quick stake_change_payment_staked_to_unstaked
          ; test_case "stake_change: payment unstaked→staked = +amt" `Quick
              stake_change_payment_unstaked_to_staked
          ; test_case "stake_change: payment to new account = -(fee+amt)"
              `Quick stake_change_payment_to_new_account
          ; test_case "stake_change: redelegate Some→Some = -fee" `Quick
              stake_change_delegation_redelegate
          ; test_case "stake_change: delegation None→None = 0" `Quick
              stake_change_delegation_noop
          ; test_case "stake_change: fee_transfer one staked = +fee" `Quick
              stake_change_fee_transfer_one_staked
          ; test_case "stake_change: fee_transfer one unstaked = 0" `Quick
              stake_change_fee_transfer_one_unstaked
          ; test_case "stake_change: fee_transfer two mixed = +f1" `Quick
              stake_change_fee_transfer_two_mixed
          ; test_case "stake_change: coinbase no-ft staked = +amt" `Quick
              stake_change_coinbase_no_ft_staked
          ; test_case "stake_change: coinbase no-ft unstaked = 0" `Quick
              stake_change_coinbase_no_ft_unstaked
          ; test_case "stake_change: coinbase+ft both staked = +amt" `Quick
              stake_change_coinbase_ft_both_staked
          ; test_case "stake_change: coinbase+ft recv staked = +(amt-fee)"
              `Quick stake_change_coinbase_ft_recv_staked
          ; test_case "stake_change: coinbase+ft ft_recv staked = +fee"
              `Quick stake_change_coinbase_ft_ft_recv_staked
          ; test_case "stake_change: coinbase+ft both unstaked = 0" `Quick
              stake_change_coinbase_ft_both_unstaked
          ] )
    ]
