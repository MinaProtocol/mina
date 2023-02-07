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

    let%test_unit "Untimed accounts fail if funds are insufficient." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        (* We need to generate an amount strictly greater than the balance,
           therefore the balance cannot be at its maximum available value. *)
        let max_balance =
          let open Balance in
          max_int - Amount.one |> Option.value ~default:zero
        in
        let%bind account =
          Account.gen_with_constrained_balance ~low:Balance.zero
            ~high:max_balance
        in
        let min_amount =
          Amount.(Balance.to_amount account.balance + of_nanomina_int_exn 1)
          |> Option.value ~default:Amount.max_int
        in
        let%bind amount = Amount.gen_incl min_amount Amount.max_int in
        let%map slot = Global_slot.gen in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result]
            ( Or_error.errorf
                !"For timed account, the requested transaction for amount \
                  %{sexp: Amount.t} at global slot %{sexp: Global_slot.t}, the \
                  balance %{sexp: Balance.t} is insufficient"
                txn_amount txn_global_slot account.balance
            |> Result.map_error ~f:(Error.tag ~tag:nsf_tag) )
            (validate_timing ~account ~txn_amount ~txn_global_slot) )
  end )
