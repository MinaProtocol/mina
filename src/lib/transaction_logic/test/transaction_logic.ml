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
      Transaction_logic.apply_zkapp_command_unchecked
        ~constraint_constants
        ~global_slot:Global_slot.(of_int 120)
        ~state_view:protocol_state ledger cmd

    (* Alice spends all her funds to create an account for Bob, who is not in the
       ledger at the beginning of the test. Expenses include:
       * 8 Mina to fund the new account;
       * 1 Mina of account creation fee (see constraint_constants above);
       * 1 Mina of transaction fee;
       For the total of 10 Mina. Transaction is expected to succeed. *)
    let%test_unit "All the money can be spent." =
      let cmd =
        zkapp_cmd
          ~fee:(alice, Fee.of_mina_int_exn 1)
          [{ sender = alice; receiver = bob; amount = Amount.of_nanomina_int_exn 1_000_000_000 }]
      in
      match run_zkapp_cmd [ (alice, Balance.of_mina_int_exn 10) ] cmd
      with
      | Ok (txn, (local_state, amt)) ->
         (try
            [%test_eq: Mina_base.Transaction_status.t]
              Applied
              txn.command.status
          with
          | e -> 
             Printf.printf "%s"
               ( Sexp.to_string
                 @@ Zk_result.sexp_of_t
                      ( txn
                      , amt
                      , local_state
                          .Mina_transaction_logic.Zkapp_command_logic.Local_state
                          .success ) );
             raise e)
      | Error e ->
         failwith (Error.to_string_hum e)
  end )
