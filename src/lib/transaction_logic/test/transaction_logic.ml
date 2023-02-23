open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Signature_lib
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

type zk_cmd_result =
  Transaction_logic.Transaction_applied.Zkapp_command_applied.t
  * Amount.Signed.t
[@@deriving sexp]

let%test_module "Test transaction logic." =
  ( module struct
    let run_zkapp_cmd known_accounts cmd =
      let open Result.Let_syntax in
      let%bind ledger = test_ledger known_accounts in
      let%map txn, (_, amt) =
        Transaction_logic.apply_zkapp_command_unchecked ~constraint_constants
          ~global_slot:Global_slot.(of_int 120)
          ~state_view:protocol_state ledger cmd
      in
      (txn, amt)

    let%test_unit "Two accounts transaction happy path." =
      Quickcheck.test
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind accounts =
          Test_account.gen
          |> Generator.list_with_length 2
          |> Generator.filter
               ~f:
                 (List.exists
                    ~f:Balance.(fun a -> a.Test_account.balance > zero) )
        in
        let%bind txn = Test_transaction.gen accounts in
        let sender =
          List.find_exn accounts ~f:(fun a ->
              Public_key.Compressed.equal a.pk txn.sender )
        in
        let sender_fee_cap =
          Balance.(sender.balance - txn.amount)
          |> Option.value_map ~default:Fee.zero
               ~f:(Fn.compose Amount.to_fee Balance.to_amount)
        in
        let%map fee = Fee.(gen_incl zero sender_fee_cap) in
        let unsigned_cmd =
          zkapp_cmd ~noncemap:(noncemap accounts) ~fee:(txn.sender, fee) [ txn ]
        in
        let keymap = keymap accounts in
        let cmd =
          Async_unix.Thread_safe.block_on_async_exn (fun () ->
              Zkapp_command_builder.replace_authorizations ~keymap unsigned_cmd )
        in
        (accounts, cmd))
        ~f:(fun (accounts, cmd) ->
          [%test_pred: zk_cmd_result Or_error.t]
            (function
              | Ok (txn, _) ->
                  Transaction_status.(equal txn.command.status Applied)
              | Error _ ->
                  false )
            (run_zkapp_cmd accounts cmd) )
  end )
