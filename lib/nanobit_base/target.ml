open Core_kernel
open Snark_params

module Stable = struct
  module V1 = struct
    type t = Tick.Field.t
    [@@deriving bin_io, sexp]
  end
end

include Stable.V1

module Field = Tick.Field
module Bigint = Tick_curve.Bigint.R

let bit_length = Snark_params.target_bit_length

let max_bigint =
  Tick.Bigint.of_bignum_bigint
    Bignum.Bigint.(pow (of_int 2) (of_int bit_length) - one)

let max = Bigint.to_field max_bigint

let constant = Tick.Cvar.constant

let of_field x =
  assert (Bigint.compare (Bigint.of_field x) max_bigint < 0);
  x
;;

let to_bigint x = Tick.Bigint.to_bignum_bigint (Bigint.of_field x)
let of_bigint n =
  let x = Tick.Bigint.of_bignum_bigint n in
  assert (Bigint.compare x max_bigint <= 0);
  Bigint.to_field x

let meets_target_unchecked t ~hash =
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
  Bigint.(to_field (div max_bigint (of_field target)))
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
    | [ x ], [ false ] -> return false_
    | [ x ], [ true ] -> return (not x)
    | [ x1; x2 ], [ true; false ] -> return (not x1)
    | [ x1; x2 ], [ false; false ] -> return false_
    | x :: xs, false :: ys ->
      let%bind r = lt_bitstring_value_msb xs ys in
      not x && r
    | x :: xs, true :: ys ->
      let%bind r = lt_bitstring_value_msb xs ys in
      not x || r
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

type _ Snarky.Request.t +=
  | Floor_divide : [ `Two_to_the of int ] * Field.t -> Field.t Snarky.Request.t

let two_to_the i =
  Bignum.Bigint.(pow (of_int 2) (of_int i))
  |> Bigint.of_bignum_bigint
  |> Bigint.to_field

let floor_divide
      ~numerator:(`Two_to_the b as numerator)
      y y_unpacked
  =
  assert (b <= Field.size_in_bits - 2);
  assert (List.length y_unpacked <= b);
  let%bind z =
    exists Typ.field
      ~request:As_prover.(map (read_var y) ~f:(fun y -> Floor_divide (numerator, y)))
      ~compute:
        As_prover.(map (read_var y) ~f:(fun y ->
          Bigint.to_field
            (Tick_curve.Bigint.R.div (Bigint.of_field (two_to_the b))
              (Bigint.of_field y))))
  in
  (* This block checks that z * y does not overflow. *)
  let%bind () =
    (* The total number of bits in z and y must be less than the field size in bits essentially
       to prevent overflow. *)
    let%bind k = Util.num_bits_upper_bound_unpacked y_unpacked in
    (* We have to check that k <= b.
       The call to [num_bits_upper_bound_unpacked] actually guarantees that k
       is <= [List.length z_unpacked = b], since it asserts that [k] is
       equal to a sum of [b] booleans, but we add an explicit check here since it
       is relatively cheap and the internals of that function might change. *)
    let%bind () =
      Checked.Assert.lte ~bit_length:(Util.num_bits_int b)
        k (Cvar.constant (Field.of_int b))
    in
    let m = Cvar.(sub (constant (Field.of_int (b + 1))) k) in
    let%bind z_unpacked = Checked.unpack z ~length:b in
    Util.assert_num_bits_upper_bound z_unpacked m
  in
  let%bind zy = Checked.mul z y in
  let numerator = Cvar.constant (two_to_the b) in
  let%map () =
    Checked.Assert.lte ~bit_length:(b + 1) zy numerator
  and () =
    Checked.Assert.lt ~bit_length:(b + 1) numerator Cvar.Infix.(zy + y)
  in
  z
;;

(* TODO: Use a "dual" variable to ensure the bit_length constraint is actually always
   enforced. *)
include Bits.Snarkable.Small(Tick)(struct let bit_length = bit_length end)

module Bits = Bits.Small(Tick.Field)(Tick.Bigint)(struct let bit_length = bit_length end)

let passes t h =
  let%map { less; _ } = Checked.compare ~bit_length h t in
  less

let field_var_to_unpacked (x : Cvar.t) = Checked.unpack ~length:bit_length x

(* floor(two_to_the bit_length / y) *)
let strength
      (y : Packed.var)
      (y_unpacked : Unpacked.var)
  =
  with_label "Target.strength" begin
    if Insecure.strength_calculation
    then
      provide_witness Typ.field
        As_prover.(map (read_var y) ~f:strength_unchecked)
    else floor_divide ~numerator:(`Two_to_the bit_length) y y_unpacked
  end
;;
