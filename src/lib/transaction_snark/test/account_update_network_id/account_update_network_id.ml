open Core
open Mina_ledger
open Mina_base
open Async
module U = Transaction_snark_tests.Util

let%test_module "Zkapp network id tests" =
  ( module struct
    let `VK vk, `Prover _ = Lazy.force U.trivial_zkapp

    let%test_unit "zkapps failed to apply with a different network id" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 (Test_spec.mk_gen ~num_transactions:1 ())
        ~f:(fun { init_ledger; specs } ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let fee_payer = (List.hd_exn specs).sender in
                  let update =
                    { Account_update.Update.noop with zkapp_uri = Set "abc" }
                  in
                  let zkapp_account_keypair = Signature_lib.Keypair.create () in
                  let spec :
                      Transaction_snark.For_tests.Single_account_update_spec.t =
                    { fee = Currency.Fee.of_nanomina_int_exn 1_000_000
                    ; fee_payer
                    ; zkapp_account_keypair
                    ; memo =
                        Signed_command_memo.create_from_string_exn
                          "invalid network id"
                    ; update
                    ; call_data = Snark_params.Tick.Field.zero
                    ; events = []
                    ; actions = []
                    }
                  in
                  let%bind zkapp_command =
                    Transaction_snark.For_tests.single_account_update
                      ~chain:Mina_signature_kind.(Other_network "invalid")
                      ~constraint_constants:U.constraint_constants spec
                  in
                  Transaction_snark.For_tests.create_trivial_zkapp_account
                    ~permissions:
                      { Permissions.user_default with set_zkapp_uri = Proof }
                    ~vk ~ledger
                    Signature_lib.Public_key.(
                      compress zkapp_account_keypair.public_key) ;
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )
  end )
