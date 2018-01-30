open Core_kernel
open Snark_params

type t = Tick.Field.t
[@@deriving bin_io]

let of_field = Fn.id

module Bigint = Tick_curve.Bigint.R

let meets_target t ~hash =
  Bigint.(compare (of_field hash) (of_field t)) < 0
;;

let assert_mem x xs =
  let open Tick in
  let open Let_syntax in
  let rec go acc = function
    | [] -> Boolean.Assert.any acc
    | y :: ys ->
      let%bind e = Checked.equal x y in
      go (e :: acc) ys
  in
  go [] xs
;;

let strength_unchecked (target : t) =
  Bigint.(to_field (div Tick_curve.field_size (of_field target)))
;;

open Tick
open Let_syntax

let boolean_compare (x : Tick.Boolean.var) (y : Tick.Boolean.var) =
  let x = (x :> Cvar.t) in
  let y = (y :> Cvar.t) in
  let%map xy = Checked.mul x y in
  let open Cvar.Infix in
  let lt = y - xy in
  let gt = x - xy in
  let eq = Cvar.constant Field.one - (lt + gt) in
  Boolean.Unsafe.(of_cvar lt, of_cvar eq, of_cvar gt)

let boolean_compare_to_value (x : Tick.Boolean.var) (y : Tick.Boolean.value) =
  let open Boolean in
  if y
  then (not x, x, false_)
  else (false_, not x, x)

let rec lt_bitstrings_msb =
  let open Boolean in
  fun (xs : Boolean.var list) (ys : Boolean.var list) ->
    match xs, ys with
    | [], [] -> return false_
    | [ x ], [ y ] -> not x && y
    | x :: xs, y :: ys ->
      let%bind tail_lt = lt_bitstrings_msb xs ys
      and (lt, eq, gt) = boolean_compare x y in
      let%bind r = eq && tail_lt in
      lt || r
    | _::_, [] | [], _::_ ->
      failwith "lt_bitstrings_msb: Got unequal length strings"

(* Someday: This could be made more efficient by simply skipping some
   bits in the disjunction. *)
let rec lt_bitstring_value_msb =
  let open Tick in
  let open Let_syntax in
  let open Boolean in
  fun (xs : Boolean.var list) (ys : Boolean.value list) ->
    match xs, ys with
    | [], [] -> return false_
    | [ x ], [ y ] ->
      let (lt, _, _) = boolean_compare_to_value x y in
      return lt
    | x :: xs, y :: ys ->
      let (lt, eq, gt) = boolean_compare_to_value x y in
      let%bind tail_lt = lt_bitstring_value_msb xs ys in
      let%bind r = eq && tail_lt in
      lt || r
    | _::_, [] | [], _::_ ->
      failwith "lt_bitstrings_msb: Got unequal length strings"

let field_size_bits_msb =
  List.init Field.size_in_bits ~f:(fun i ->
    Bigint.test_bit Tick_curve.field_size
      (Field.size_in_bits - 1 - i))

let bits_msb =
  fun x ->
    let%bind bs = Checked.unpack ~length:Field.size_in_bits x >>| List.rev in
    let%map () =
      lt_bitstring_value_msb bs field_size_bits_msb >>= Boolean.Assert.is_true
    in
    bs

include Bits.Snarkable.Field(Tick)

(* floor(size of field / y) *)
let strength
      (y : Packed.var)
      (y_unpacked : Unpacked.var)
  =
  with_label "Target.strength" begin
  (* TODO: Critical.
    This computation is totally unchecked. *)
    exists Var_spec.field
      As_prover.(map (read_var y) ~f:strength_unchecked)
  end
;;
