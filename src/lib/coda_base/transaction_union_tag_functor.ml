open Core_kernel
open Snarky_intf

module Make (Impl : Tick_S) = struct
  open Impl

  type t = Payment | Stake_delegation | Fee_transfer | Coinbase
  [@@deriving enum, eq, sexp]

  let gen =
    Quickcheck.Generator.map (Int.gen_incl min max) ~f:(fun i ->
        Option.value_exn (of_enum i) )

  type var = Boolean.var * Boolean.var

  let to_bits = function
    | Payment ->
        (false, false)
    | Stake_delegation ->
        (true, false)
    | Fee_transfer ->
        (false, true)
    | Coinbase ->
        (true, true)

  let of_bits = function
    | false, false ->
        Payment
    | true, false ->
        Stake_delegation
    | false, true ->
        Fee_transfer
    | true, true ->
        Coinbase

  let%test_unit "to_bool of_bool inv" =
    let open Quickcheck in
    test (Generator.tuple2 Bool.quickcheck_generator Bool.quickcheck_generator)
      ~f:(fun b -> assert (b = to_bits (of_bits b)))

  let typ =
    Typ.transport Typ.(Boolean.typ * Boolean.typ) ~there:to_bits ~back:of_bits

  module Checked = struct
    open Let_syntax

    let constant t =
      let x, y = to_bits t in
      Boolean.(var_of_value x, var_of_value y)

    (* someday: Make these all cached *)

    let is_payment (b0, b1) = Boolean.((not b0) && not b1)

    let is_fee_transfer (b0, b1) = Boolean.((not b0) && b1)

    let is_stake_delegation (b0, b1) = Boolean.(b0 && not b1)

    let is_coinbase (b0, b1) = Boolean.(b0 && b1)

    let is_user_command (_, b1) = return (Boolean.not b1)
  end
end
