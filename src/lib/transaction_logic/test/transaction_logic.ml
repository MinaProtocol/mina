open Core_kernel
open Mina_numbers
open Currency
open Helpers
module Transaction_logic = Mina_transaction_logic.Make (Ledger)

module Zk_result = struct
  type t =
    Transaction_logic.Transaction_applied.Zkapp_command_applied.t
    * Amount.Signed.t
    * bool
  [@@deriving sexp]
end

let constraint_constants =
  { Genesis_constants.Constraint_constants.for_unit_tests with
    account_creation_fee = Fee.of_mina_int_exn 1
  }

let%test_module "Test transaction logic." =
  ( module struct
    let run_zkapp_cmd known_accounts cmd =
      let open Result.Let_syntax in
      let%bind ledger = test_ledger known_accounts in
      Transaction_logic.apply_zkapp_command_unchecked ~constraint_constants
        ~global_slot:Global_slot.(of_int 120)
        ~state_view:protocol_state ledger cmd

    let%test_unit "All the money can be spent." =
      let unsigned_cmd =
        zkapp_cmd
          ~noncemap:(noncemap [ alice; bob ])
          ~fee:(alice.pk, Fee.of_mina_int_exn 1)
          [ { sender = alice.pk
            ; receiver = bob.pk
            ; amount = Amount.of_nanomina_int_exn 1_000_000_000
            }
          ]
      in
      let cmd =
        Async_unix.Thread_safe.block_on_async_exn (fun () ->
            Zkapp_command_builder.replace_authorizations ~keymap unsigned_cmd )
      in
      match run_zkapp_cmd [ (alice.pk, Balance.of_mina_int_exn 10) ] cmd with
      | Ok (txn, (local_state, amt)) -> (
          try
            [%test_eq: Mina_base.Transaction_status.t] Applied
              txn.command.status
          with e ->
            Printf.printf "%s"
              ( Sexp.to_string
              @@ Zk_result.sexp_of_t
                   ( txn
                   , amt
                   , local_state
                       .Mina_transaction_logic.Zkapp_command_logic.Local_state
                        .success ) ) ;
            raise e )
      | Error e ->
          Printf.printf "%s"
            (Sexp.to_string @@ Mina_base.Zkapp_command.sexp_of_t cmd) ;
          failwith (Error.to_string_hum e)
  end )
