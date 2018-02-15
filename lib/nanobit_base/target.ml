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

let bit_length = Field.size_in_bits - 2

let max =
  Field.(sub (Tick.Util.two_to_the bit_length) (of_int 1))

let max_bigint = Bigint.of_field max

let constant = Tick.Cvar.constant

let of_field x =
  assert (Bigint.compare (Bigint.of_field x) max_bigint <= 0);
  x
;;

let to_bigint x = Snark_params.bigint_of_tick_bigint (Bigint.of_field x)
let of_bigint n =
  let x = Snark_params.tick_bigint_of_bigint n in
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

let floor_divide
      ~numerator:(`Two_to_the b)
      y y_unpacked
  =
  assert (b <= Field.size_in_bits - 2);
  assert (List.length y_unpacked <= b);
  let%bind z =
    testify Var_spec.field
      As_prover.(map (read_var y) ~f:(fun y ->
        Bigint.to_field
          (Tick_curve.Bigint.R.div (Bigint.of_field (Util.two_to_the b))
            (Bigint.of_field y))))
  in
  (* This block checks that z * y does not overflow. *)
  let%bind () =
    let%bind z_unpacked = Checked.unpack z ~length:b in
    let%bind k = Util.num_bits_upper_bound_unpacked y_unpacked in
    let m = Cvar.(sub (constant (Field.of_int (b + 1))) k) in
    (* TODO: This implicitly checks that k <= b + 1 (since it unpacks (b+1 - k) into
        a small number) but it would be good for it to be more explicit *)
    let%bind m_unpacked = Checked.unpack m ~length:Util.size_in_bits_size_in_bits in
    Util.assert_num_bits_upper_bound z_unpacked m_unpacked
  in
  let%bind zy = Checked.mul z y in
  let numerator = Cvar.constant (Util.two_to_the b) in
  let%map () =
    Util.Assert.lte ~bit_length:(b + 1) zy numerator
  and () =
    Util.Assert.lt ~bit_length:(b + 1) numerator Cvar.Infix.(zy + y)
  in
  z
;;

(* TODO: Use a "dual" variable to ensure the bit_length constraint is actually always
   enforced. *)
include Bits.Snarkable.Field_backed(Tick)(struct let bit_length = bit_length end)

let passes t h =
  let%map { less_or_equal; _ } = Tick.Util.compare ~bit_length h t in
  less_or_equal

let pack : Unpacked.var -> Packed.var = Tick.Checked.pack

let var_to_unpacked (x : Cvar.t) = Checked.unpack x

(* floor(size of field / y) *)
let strength
      (y : Packed.var)
      (y_unpacked : Unpacked.var)
  =
  with_label "Target.strength" begin
    if Insecure.strength_calculation
    then
      testify Var_spec.field
        As_prover.(map (read_var y) ~f:strength_unchecked)
    else floor_divide ~numerator:(`Two_to_the bit_length) y y_unpacked
  end
;;
