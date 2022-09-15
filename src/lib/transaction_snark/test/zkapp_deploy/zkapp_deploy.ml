open Core
open Mina_ledger
module U = Transaction_snark_tests.Util
module Spec = Transaction_snark.For_tests.Spec
open Mina_base

let%test_module "Snapp deploy tests" =
  ( module struct
    let memo = Signed_command_memo.create_from_string_exn "Snapp deploy tests"

    let constraint_constants = U.constraint_constants

    let%test_unit "create a new snapp account/deploy a smart contract" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let spec = List.hd_exn specs in
                  let fee = Currency.Fee.of_int 1_000_000 in
                  let amount = Currency.Amount.of_int 10_000_000_000 in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount
                    ; zkapp_account_keypairs = [ new_kp ]
                    ; memo
                    ; new_zkapp_account = true
                    ; snapp_update = Account_update.Update.dummy
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; sequence_events = []
                    ; preconditions = None
                    }
                  in
                  let zkapp_command =
                    Transaction_snark.For_tests.deploy_snapp test_spec
                      ~constraint_constants
                  in
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    let%test_unit "deploy multiple ZkApps" =
      let open Mina_transaction_logic.For_tests in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind spec, kp1 = U.gen_snapp_ledger in
        let%map kps =
          Quickcheck.Generator.list_with_length 2 Signature_lib.Keypair.gen
        in
        (spec, kp1 :: kps)
      in
      Quickcheck.test ~trials:1 gen ~f:(fun ({ init_ledger; specs }, kps) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let spec = List.hd_exn specs in
                  let fee = Currency.Fee.of_int 1_000_000 in
                  let amount = Currency.Amount.of_int 7_000_000_000 in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount
                    ; zkapp_account_keypairs = kps
                    ; memo
                    ; new_zkapp_account = true
                    ; snapp_update = Account_update.Update.dummy
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; sequence_events = []
                    ; preconditions = None
                    }
                  in
                  let zkapp_command =
                    Transaction_snark.For_tests.deploy_snapp test_spec
                      ~constraint_constants
                  in
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    let%test_unit "change a non-snapp account to snapp account/deploy a smart \
                   contract" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, _new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let spec = List.hd_exn specs in
                  let fee = Currency.Fee.of_int 1_000_000 in
                  let amount = Currency.Amount.of_int 10_000_000_000 in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount
                    ; zkapp_account_keypairs = [ fst spec.sender ]
                    ; memo
                    ; new_zkapp_account = false
                    ; snapp_update = Account_update.Update.dummy
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; sequence_events = []
                    ; preconditions = None
                    }
                  in
                  let zkapp_command =
                    Transaction_snark.For_tests.deploy_snapp test_spec
                      ~constraint_constants
                  in
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    let%test_unit "change a non-snapp account to snapp account/deploy a smart \
                   contract- different fee payer" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, _new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let spec0 = List.nth_exn specs 0 in
                  let spec1 = List.nth_exn specs 1 in
                  let fee = Currency.Fee.of_int 1_000_000 in
                  let amount = Currency.Amount.of_int 10_000_000_000 in
                  let test_spec : Spec.t =
                    { sender = spec0.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount
                    ; zkapp_account_keypairs = [ fst spec1.sender ]
                    ; memo
                    ; new_zkapp_account = false
                    ; snapp_update = Account_update.Update.dummy
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; sequence_events = []
                    ; preconditions = None
                    }
                  in
                  let zkapp_command =
                    Transaction_snark.For_tests.deploy_snapp test_spec
                      ~constraint_constants
                  in
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )

    let%test_unit "Fails to deploy if the account is not present and amount is \
                   insufficient" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let spec = List.hd_exn specs in
                  let fee = Currency.Fee.of_int 1_000_000 in
                  (*transfering zero should cause the transaction to fail if the account is not already created*)
                  let amount = Currency.Amount.zero in
                  let test_spec : Spec.t =
                    { sender = spec.sender
                    ; fee
                    ; fee_payer = None
                    ; receivers = []
                    ; amount
                    ; zkapp_account_keypairs = [ new_kp ]
                    ; memo
                    ; new_zkapp_account = false
                    ; snapp_update = Account_update.Update.dummy
                    ; current_auth = Permissions.Auth_required.Signature
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; sequence_events = []
                    ; preconditions = None
                    }
                  in
                  let zkapp_command =
                    Transaction_snark.For_tests.deploy_snapp test_spec
                      ~constraint_constants
                  in
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn ledger
                    ~expected_failure:Invalid_fee_excess [ zkapp_command ] ) ) )
  end )
