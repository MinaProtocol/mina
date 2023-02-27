open Core_kernel
open Currency
open Mina_base
open Mina_numbers
open Helpers
open Update_utils
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

(* The function under test is quite slow, so keep the trials count low
   so that tests finish in a reasonable amount of time. *)
let trials = 10

let balance_to_fee = Fn.compose Amount.to_fee Balance.to_amount

(* This module tests the "pure" transaction logic implemented in this library.
   By "pure" we mean that ZK SNARKs aren't used for verification, instead all
   signatures and proofs are assumed to be valid. These verification details
   are provided by the functor parameters (Inputs module) and a full-featured
   implementation leveraging ZK SNARKs is given in transaction_snark library.

   As a consequence, we don't bother with constructing correct signatures or
   proofs here. We just give dummy signatures because this implementation
   accepts anything anyway. Note, however, that this implementation DOES check
   whether SOME signature or proof is given whenever required. It just doesn't
   validate them. *)
let%test_module "Test transaction logic." =
  ( module struct
    let run_zkapp_cmd ~fee_payer ~fee ~accounts txns =
      let open Result.Let_syntax in
      let cmd =
        zkapp_cmd ~noncemap:(noncemap accounts) ~fee:(fee_payer, fee) txns
      in
      let%bind ledger = test_ledger accounts in
      let%map txn, (_, amt) =
        Transaction_logic.apply_zkapp_command_unchecked ~constraint_constants
          ~global_slot:Global_slot.(of_int 120)
          ~state_view:protocol_state ledger cmd
      in
      (txn, amt)

    let%test_unit "Many transactions between distinct accounts." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Quickcheck.Generator.Let_syntax in
        let%bind accs_and_txns =
          Generator.list_non_empty Simple_txn.gen_account_pair_and_txn
          (* Generating too many transactions makes this test take too much time. *)
          |> Generator.filter ~f:(fun l -> List.length l < 4)
        in
        let account_pairs, txns = List.unzip accs_and_txns in
        let accounts =
          List.concat_map account_pairs ~f:(fun (a, b) -> [ a; b ])
        in
        (* Select a receiver to pay the fee. *)
        let%bind fee_payer =
          Generator.of_list @@ List.map ~f:snd account_pairs
        in
        let%map fee = Fee.(gen_incl zero @@ balance_to_fee fee_payer.balance) in
        (fee_payer.pk, fee, accounts, (txns :> transaction list)))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: zk_cmd_result Or_error.t]
            (function
              | Ok (txn, _) ->
                  Transaction_status.(equal txn.command.status Applied)
              | Error _ ->
                  false )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Fee payer must be able to pay the fee." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind (sender, receiver), txn =
          Simple_txn.gen_account_pair_and_txn
          |> Generator.filter
               ~f:Balance.(fun ((a, _), _) -> a.balance < max_int)
        in
        let accounts = [ sender; receiver ] in
        (* Make sure that fee is too high. *)
        let min_fee =
          Balance.(sender.balance - txn#amount)
          |> Option.value_map ~default:Fee.zero ~f:balance_to_fee
          |> Fee.(fun f -> f + of_nanomina_int_exn 1)
          |> Option.value ~default:Fee.max_int
        in
        let max_fee =
          Fee.(min_fee + of_mina_int_exn 10)
          |> Option.value ~default:Fee.max_int
        in
        let%map fee = Fee.(gen_incl min_fee max_fee) in
        (sender.pk, fee, accounts, [ (txn :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: zk_cmd_result Or_error.t]
            (function
              | Ok (txn, _) ->
                  Transaction_status.(
                    equal txn.command.status
                      (Failed [ []; [ Overflow ]; [ Cancelled ] ]))
              | Error e ->
                  String.is_substring (Error.to_string_hum e)
                    ~substring:"Overflow" )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Currency cannot be created out of thin air." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind account =
          Generator.filter
            ~f:Balance.(fun a -> a.balance < max_int)
            Test_account.gen
        in
        let max_amount =
          Balance.(max_int - to_amount account.balance)
          |> Option.value_map ~default:Amount.zero ~f:Balance.to_amount
        in
        let%bind unsigned_amount =
          Amount.(gen_incl (of_nanomina_int_exn 1) max_amount)
        in
        let amount = Amount.Signed.of_unsigned unsigned_amount in
        let update = Single.make ~account:account.pk amount in
        let%map fee = Fee.(gen_incl zero (balance_to_fee account.balance)) in
        (account.pk, fee, [ account ], [ (update :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: zk_cmd_result Or_error.t]
            (function
              | Ok (txn, _) ->
                  Transaction_status.(
                    equal txn.command.status
                      (Failed [ []; [ Invalid_fee_excess ] ]))
              | Error _ ->
                  false )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )

    let%test_unit "Currency cannot be destroyed." =
      Quickcheck.test ~trials
        (let open Quickcheck in
        let open Generator.Let_syntax in
        let%bind unsigned_amount =
          Amount.(gen_incl (of_nanomina_int_exn 1) max_int)
        in
        let%bind account =
          Generator.filter
            ~f:Amount.(fun a -> Balance.to_amount a.balance >= unsigned_amount)
            Test_account.gen
        in
        let amount = Amount.Signed.(negate @@ of_unsigned unsigned_amount) in
        let update = Single.make ~account:account.pk amount in
        let max_fee =
          Balance.(account.balance - unsigned_amount)
          |> Option.value_map ~default:Fee.zero ~f:balance_to_fee
        in
        let%map fee = Fee.(gen_incl zero max_fee) in
        (account.pk, fee, [ account ], [ (update :> transaction) ]))
        ~f:(fun (fee_payer, fee, accounts, txns) ->
          [%test_pred: zk_cmd_result Or_error.t]
            (function
              | Ok (txn, _) ->
                  Transaction_status.(
                    equal txn.command.status
                      (Failed [ []; [ Invalid_fee_excess ] ]))
              | Error _ ->
                  false )
            (run_zkapp_cmd ~fee_payer ~fee ~accounts txns) )
    end )
