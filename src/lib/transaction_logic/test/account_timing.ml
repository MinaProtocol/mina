open! Core_kernel
open! Mina_transaction_logic
open Currency
open Mina_base
open Mina_numbers

type txn_result =
  ((Global_slot.t, Balance.t, Amount.t) Account_timing.tt, Error.t) Result.t
[@@deriving compare, sexp]

let%test_module "Test account timing." =
  ( module struct
    let%test_unit "Untimed accounts succeed if they have enough funds." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen in
        let%bind amount =
          Amount.(gen_incl zero (Balance.to_amount account.balance))
        in
        let%map slot = Global_slot.gen in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result] (Ok Account.Timing.Poly.Untimed)
            (validate_timing ~account ~txn_amount ~txn_global_slot) )
  end )
