open Core
open Mina_ledger
module U = Transaction_snark_tests.Util

let%test_module "Zkapp network id tests" =
  ( module struct
    let%test_unit "zkapps failed to apply with a different network id" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:1 (Test_spec.mk_gen ~num_transactions:2 ())
        ~f:(fun { init_ledger; specs } ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let zkapp_command =
                    account_update_send
                      ~signature_kind:
                        (Some Mina_signature_kind.(Other_network "invalid"))
                      (List.hd_exn specs)
                  in
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  U.check_zkapp_command_with_merges_exn ledger [ zkapp_command ] ) ) )
  end )
