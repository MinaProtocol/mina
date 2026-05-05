(** Transaction SNARK (constraint-check) tests for stake_change.

    Each test mirrors a row of the coverage table in
    [docs/unstaking-stake-change.md] (and our unchecked-logic tests in
    [src/lib/transaction_logic/test/transaction_logic/stake_change.ml]),
    but exercises the non-zkApp base circuit via [U.test_transaction_union],
    which calls [Transaction_snark.check_transaction] with the
    [~stake_change] computed from the applied transaction.

    A failure here means the circuit's reduced form disagrees with the
    unchecked expanded form for that scenario. *)

open Core_kernel
open Mina_base
open Currency
open Signature_lib
module U = Transaction_snark_tests.Util
module Ledger = Mina_ledger.Ledger

let%test_module "stake_change in the transaction SNARK" =
  ( module struct
    let ledger_depth = U.ledger_depth

    let constraint_constants = U.constraint_constants

    (* Overwrite an existing account's delegate field. Panics if the account
       isn't in the ledger. *)
    let set_delegate ledger pk new_delegate =
      let acc_id = Account_id.create pk Token_id.default in
      let loc = Option.value_exn (Ledger.location_of_account ledger acc_id) in
      let acc = Option.value_exn (Ledger.get ledger loc) in
      Ledger.set ledger loc { acc with delegate = new_delegate }

    (* Overwrite an existing account's permissions field. Panics if the
       account isn't in the ledger. *)
    let set_permissions ledger pk new_permissions =
      let acc_id = Account_id.create pk Token_id.default in
      let loc = Option.value_exn (Ledger.location_of_account ledger acc_id) in
      let acc = Option.value_exn (Ledger.get ledger loc) in
      Ledger.set ledger loc { acc with permissions = new_permissions }

    let memo =
      Signed_command_memo.create_by_digesting_string_exn
        (Test_util.arbitrary_string
           ~len:Signed_command_memo.max_digestible_string_length )

    (* Generate [n] fresh wallets and populate [ledger] with their accounts. *)
    let with_ledger_of_wallets ~n f =
      let wallets = Quickcheck.random_value (U.Wallet.random_wallets ~n ()) in
      Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
          Array.iter wallets ~f:(fun { account; _ } ->
              Ledger.create_new_account_exn ledger
                (Account.identifier account)
                account ) ;
          f ledger wallets )

    let fee = Fee.of_mina_int_exn 1

    (* ------------------------------------------------------------ *)
    (* Payment                                                      *)
    (* ------------------------------------------------------------ *)

    (* unstaking_tx_case_1.1 *)
    let%test_unit "Payment success, neither staked" =
      Test_util.with_randomness 1 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let txn =
                U.Wallet.user_command_with_wallet wallets ~sender:0 ~receiver:1
                  8_000_000_000 fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_1.2 *)
    let%test_unit "Payment success, both staked" =
      Test_util.with_randomness 2 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let sender_pk = wallets.(0).account.public_key in
              let receiver_pk = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger sender_pk (Some validator_pk) ;
              set_delegate ledger receiver_pk (Some validator_pk) ;
              let txn =
                U.Wallet.user_command_with_wallet wallets ~sender:0 ~receiver:1
                  8_000_000_000 fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_1.3 *)
    let%test_unit "Payment success, sender staked only" =
      Test_util.with_randomness 3 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let sender_pk = wallets.(0).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger sender_pk (Some validator_pk) ;
              let txn =
                U.Wallet.user_command_with_wallet wallets ~sender:0 ~receiver:1
                  8_000_000_000 fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_1.4 *)
    let%test_unit "Payment success, receiver staked only" =
      Test_util.with_randomness 4 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let receiver_pk = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger receiver_pk (Some validator_pk) ;
              let txn =
                U.Wallet.user_command_with_wallet wallets ~sender:0 ~receiver:1
                  8_000_000_000 fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* Payment fail: receiver's [receive] permission rejects, so the body
       fails with Update_not_permitted_balance. The fee_payer step has
       already committed by then (fee debited, nonce bumped), leaving
       status = Failed and stake_change = −fee·fp_staked. *)
    (* unstaking_tx_case_2.1 *)
    let%test_unit "Payment fail (receiver receive=Impossible), sender staked" =
      Test_util.with_randomness 14 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let sender_pk = wallets.(0).account.public_key in
              let receiver_pk = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger sender_pk (Some validator_pk) ;
              set_permissions ledger receiver_pk
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                } ;
              let txn =
                U.Wallet.user_command_with_wallet wallets ~sender:0 ~receiver:1
                  8_000_000_000 fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* ------------------------------------------------------------ *)
    (* Stake_delegation                                             *)
    (* ------------------------------------------------------------ *)

    (* unstaking_tx_case_3 *)
    let%test_unit "Delegation Some→Some" =
      Test_util.with_randomness 5 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let delegator = wallets.(0) in
              let old_delegate_pk = wallets.(1).account.public_key in
              let new_delegate_pk = wallets.(2).account.public_key in
              set_delegate ledger delegator.account.public_key
                (Some old_delegate_pk) ;
              let txn =
                U.Wallet.stake_delegation ~fee_payer:delegator
                  ~delegate_pk:new_delegate_pk fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_4 *)
    let%test_unit "Delegation Some→None (opt-out)" =
      Test_util.with_randomness 6 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let delegator = wallets.(0) in
              let old_delegate_pk = wallets.(1).account.public_key in
              set_delegate ledger delegator.account.public_key
                (Some old_delegate_pk) ;
              let txn =
                U.Wallet.stake_delegation ~fee_payer:delegator
                  ~delegate_pk:Public_key.Compressed.empty fee
                  Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_5 *)
    let%test_unit "Delegation None→Some (opt-in)" =
      Test_util.with_randomness 7 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let delegator = wallets.(0) in
              let new_delegate_pk = wallets.(1).account.public_key in
              let txn =
                U.Wallet.stake_delegation ~fee_payer:delegator
                  ~delegate_pk:new_delegate_pk fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_6 *)
    let%test_unit "Delegation None→None" =
      Test_util.with_randomness 8 (fun () ->
          with_ledger_of_wallets ~n:1 (fun ledger wallets ->
              let delegator = wallets.(0) in
              let txn =
                U.Wallet.stake_delegation ~fee_payer:delegator
                  ~delegate_pk:Public_key.Compressed.empty fee
                  Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_7.3 *)
    let%test_unit "Delegation failed (unknown receiver), delegator staked" =
      Test_util.with_randomness 15 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let delegator = wallets.(0) in
              let old_delegate_pk = wallets.(1).account.public_key in
              let unknown_pk =
                Quickcheck.random_value Public_key.Compressed.gen
              in
              set_delegate ledger delegator.account.public_key
                (Some old_delegate_pk) ;
              let txn =
                U.Wallet.stake_delegation ~fee_payer:delegator
                  ~delegate_pk:unknown_pk fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* unstaking_tx_case_7.1 *)
    let%test_unit "Delegation not permitted (set_delegate=Proof)" =
      Test_util.with_randomness 13 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let delegator = wallets.(0) in
              let old_delegate_pk = wallets.(1).account.public_key in
              let new_delegate_pk = wallets.(2).account.public_key in
              set_delegate ledger delegator.account.public_key
                (Some old_delegate_pk) ;
              set_permissions ledger delegator.account.public_key
                { Permissions.user_default with
                  set_delegate = Permissions.Auth_required.Proof
                } ;
              let txn =
                U.Wallet.stake_delegation ~fee_payer:delegator
                  ~delegate_pk:new_delegate_pk fee Account.Nonce.zero memo
              in
              U.test_transaction_union ledger (Command (Signed_command txn)) ) )

    (* ------------------------------------------------------------ *)
    (* TODO: deferred coverage-table row                            *)
    (*                                                              *)
    (* Payment, fail. The row's formula is −fee·fp. A failed        *)
    (* payment applies (fee deducted, nonce incremented) but        *)
    (* body does not transfer. In the SNARK path we'd need to       *)
    (* construct a tx that fails via the user_command_failure       *)
    (* channel rather than causing apply_transactions itself to     *)
    (* error out — see the same TODO in the unchecked tests.        *)
    (* ------------------------------------------------------------ *)

    (* ------------------------------------------------------------ *)
    (* Fee_transfer                                                 *)
    (* ------------------------------------------------------------ *)

    let ft_single ~recipient_pk ~fee : Fee_transfer.Single.t =
      Fee_transfer.Single.create ~receiver_pk:recipient_pk ~fee
        ~fee_token:Token_id.default

    (* unstaking_tx_case_8.1 *)
    let%test_unit "Fee_transfer one single, staked" =
      Test_util.with_randomness 9 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let recipient = wallets.(0) in
              let validator_pk = wallets.(1).account.public_key in
              set_delegate ledger recipient.account.public_key
                (Some validator_pk) ;
              let ft =
                Or_error.ok_exn
                  (Fee_transfer.of_singles
                     (`One
                       (ft_single ~recipient_pk:recipient.account.public_key
                          ~fee ) ) )
              in
              U.test_transaction_union ledger (Fee_transfer ft) ) )

    (* unstaking_tx_case_8.3 *)
    let%test_unit "Fee_transfer one single, receive rejected" =
      Test_util.with_randomness 91 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let recipient = wallets.(0) in
              let validator_pk = wallets.(1).account.public_key in
              set_delegate ledger recipient.account.public_key
                (Some validator_pk) ;
              set_permissions ledger recipient.account.public_key
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                } ;
              let ft =
                Or_error.ok_exn
                  (Fee_transfer.of_singles
                     (`One
                       (ft_single ~recipient_pk:recipient.account.public_key
                          ~fee ) ) )
              in
              U.test_transaction_union ledger (Fee_transfer ft) ) )

    (* unstaking_tx_case_9.1 *)
    let%test_unit "Fee_transfer two singles, only pk1 staked" =
      Test_util.with_randomness 10 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let pk1 = wallets.(0).account.public_key in
              let pk2 = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger pk1 (Some validator_pk) ;
              let fee1 = Fee.of_mina_int_exn 1 in
              let fee2 = Fee.of_mina_int_exn 2 in
              let ft =
                Or_error.ok_exn
                  (Fee_transfer.of_singles
                     (`Two
                       ( ft_single ~recipient_pk:pk1 ~fee:fee1
                       , ft_single ~recipient_pk:pk2 ~fee:fee2 ) ) )
              in
              U.test_transaction_union ledger (Fee_transfer ft) ) )

    (* unstaking_tx_case_9.2 *)
    let%test_unit "Fee_transfer two singles, fp slot rejected" =
      Test_util.with_randomness 92 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let pk1 = wallets.(0).account.public_key in
              let pk2 = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger pk1 (Some validator_pk) ;
              set_delegate ledger pk2 (Some validator_pk) ;
              set_permissions ledger pk2
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                } ;
              let fee1 = Fee.of_mina_int_exn 1 in
              let fee2 = Fee.of_mina_int_exn 2 in
              let ft =
                Or_error.ok_exn
                  (Fee_transfer.of_singles
                     (`Two
                       ( ft_single ~recipient_pk:pk1 ~fee:fee1
                       , ft_single ~recipient_pk:pk2 ~fee:fee2 ) ) )
              in
              U.test_transaction_union ledger (Fee_transfer ft) ) )

    (* unstaking_tx_case_9.3 *)
    let%test_unit "Fee_transfer two singles, rcv slot rejected" =
      Test_util.with_randomness 93 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let pk1 = wallets.(0).account.public_key in
              let pk2 = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger pk1 (Some validator_pk) ;
              set_delegate ledger pk2 (Some validator_pk) ;
              set_permissions ledger pk1
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                } ;
              let fee1 = Fee.of_mina_int_exn 1 in
              let fee2 = Fee.of_mina_int_exn 2 in
              let ft =
                Or_error.ok_exn
                  (Fee_transfer.of_singles
                     (`Two
                       ( ft_single ~recipient_pk:pk1 ~fee:fee1
                       , ft_single ~recipient_pk:pk2 ~fee:fee2 ) ) )
              in
              U.test_transaction_union ledger (Fee_transfer ft) ) )

    (* unstaking_tx_case_9.4 *)
    let%test_unit "Fee_transfer two singles, both rejected" =
      Test_util.with_randomness 94 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let pk1 = wallets.(0).account.public_key in
              let pk2 = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger pk1 (Some validator_pk) ;
              set_delegate ledger pk2 (Some validator_pk) ;
              let reject =
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                }
              in
              set_permissions ledger pk1 reject ;
              set_permissions ledger pk2 reject ;
              let fee1 = Fee.of_mina_int_exn 1 in
              let fee2 = Fee.of_mina_int_exn 2 in
              let ft =
                Or_error.ok_exn
                  (Fee_transfer.of_singles
                     (`Two
                       ( ft_single ~recipient_pk:pk1 ~fee:fee1
                       , ft_single ~recipient_pk:pk2 ~fee:fee2 ) ) )
              in
              U.test_transaction_union ledger (Fee_transfer ft) ) )

    (* ------------------------------------------------------------ *)
    (* Coinbase                                                     *)
    (* ------------------------------------------------------------ *)

    let coinbase_amount = Amount.of_mina_int_exn 720

    (* unstaking_tx_case_10.1 *)
    let%test_unit "Coinbase no fee_transfer, staked" =
      Test_util.with_randomness 11 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let receiver = wallets.(0) in
              let validator_pk = wallets.(1).account.public_key in
              set_delegate ledger receiver.account.public_key (Some validator_pk) ;
              let cb =
                Or_error.ok_exn
                  (Coinbase.create ~amount:coinbase_amount
                     ~receiver:receiver.account.public_key ~fee_transfer:None )
              in
              U.test_transaction_union ledger (Coinbase cb) ) )

    (* unstaking_tx_case_10.3 *)
    let%test_unit "Coinbase no fee_transfer, receive rejected" =
      Test_util.with_randomness 103 (fun () ->
          with_ledger_of_wallets ~n:2 (fun ledger wallets ->
              let receiver = wallets.(0) in
              let validator_pk = wallets.(1).account.public_key in
              set_delegate ledger receiver.account.public_key (Some validator_pk) ;
              set_permissions ledger receiver.account.public_key
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                } ;
              let cb =
                Or_error.ok_exn
                  (Coinbase.create ~amount:coinbase_amount
                     ~receiver:receiver.account.public_key ~fee_transfer:None )
              in
              U.test_transaction_union ledger (Coinbase cb) ) )

    (* unstaking_tx_case_11.1 *)
    let%test_unit "Coinbase with fee_transfer, only cb receiver staked" =
      Test_util.with_randomness 12 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let receiver_pk = wallets.(0).account.public_key in
              let ft_recipient_pk = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger receiver_pk (Some validator_pk) ;
              let ft =
                Coinbase_fee_transfer.create ~receiver_pk:ft_recipient_pk
                  ~fee:constraint_constants.account_creation_fee
              in
              let cb =
                Or_error.ok_exn
                  (Coinbase.create ~amount:coinbase_amount ~receiver:receiver_pk
                     ~fee_transfer:(Some ft) )
              in
              U.test_transaction_union ledger (Coinbase cb) ) )

    (* unstaking_tx_case_11.2 *)
    let%test_unit "Coinbase with fee_transfer, sw rejected" =
      Test_util.with_randomness 112 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let receiver_pk = wallets.(0).account.public_key in
              let ft_recipient_pk = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger receiver_pk (Some validator_pk) ;
              set_delegate ledger ft_recipient_pk (Some validator_pk) ;
              set_permissions ledger ft_recipient_pk
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                } ;
              let ft =
                Coinbase_fee_transfer.create ~receiver_pk:ft_recipient_pk
                  ~fee:constraint_constants.account_creation_fee
              in
              let cb =
                Or_error.ok_exn
                  (Coinbase.create ~amount:coinbase_amount ~receiver:receiver_pk
                     ~fee_transfer:(Some ft) )
              in
              U.test_transaction_union ledger (Coinbase cb) ) )

    (* unstaking_tx_case_11.3 *)
    let%test_unit "Coinbase with fee_transfer, bp rejected" =
      Test_util.with_randomness 113 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let receiver_pk = wallets.(0).account.public_key in
              let ft_recipient_pk = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger receiver_pk (Some validator_pk) ;
              set_delegate ledger ft_recipient_pk (Some validator_pk) ;
              set_permissions ledger receiver_pk
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                } ;
              let ft =
                Coinbase_fee_transfer.create ~receiver_pk:ft_recipient_pk
                  ~fee:constraint_constants.account_creation_fee
              in
              let cb =
                Or_error.ok_exn
                  (Coinbase.create ~amount:coinbase_amount ~receiver:receiver_pk
                     ~fee_transfer:(Some ft) )
              in
              U.test_transaction_union ledger (Coinbase cb) ) )

    (* unstaking_tx_case_11.4 *)
    let%test_unit "Coinbase with fee_transfer, both rejected" =
      Test_util.with_randomness 114 (fun () ->
          with_ledger_of_wallets ~n:3 (fun ledger wallets ->
              let receiver_pk = wallets.(0).account.public_key in
              let ft_recipient_pk = wallets.(1).account.public_key in
              let validator_pk = wallets.(2).account.public_key in
              set_delegate ledger receiver_pk (Some validator_pk) ;
              set_delegate ledger ft_recipient_pk (Some validator_pk) ;
              let reject =
                { Permissions.user_default with
                  receive = Permissions.Auth_required.Impossible
                }
              in
              set_permissions ledger receiver_pk reject ;
              set_permissions ledger ft_recipient_pk reject ;
              let ft =
                Coinbase_fee_transfer.create ~receiver_pk:ft_recipient_pk
                  ~fee:constraint_constants.account_creation_fee
              in
              let cb =
                Or_error.ok_exn
                  (Coinbase.create ~amount:coinbase_amount ~receiver:receiver_pk
                     ~fee_transfer:(Some ft) )
              in
              U.test_transaction_union ledger (Coinbase cb) ) )
  end )
