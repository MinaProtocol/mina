open Core_kernel
open Nanobit_base
open Snark_params

type t = Tick.Field.t
[@@deriving bin_io]

let of_field = Fn.id

module Bigint = Tick_curve.Bigint.R

let meets_target t ~hash =
  Bigint.(compare (of_field hash) (of_field t)) < 0
;;

include Bits.Snarkable.Field(Tick)

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


let num_bits_int =
  let rec go acc n =
    if n = 0
    then acc
    else go (1 + acc) (n lsr 1)
  in
  go 0
;;

open Tick
open Let_syntax

let size_in_bits_size_in_bits = num_bits_int Field.size_in_bits

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
;;

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

let bits_msb =
  let field_size_bits_msb =
    List.init Field.size_in_bits ~f:(fun i ->
      Bigint.test_bit Tick_curve.field_size
        (Field.size_in_bits - 1 - i))
  in
  fun x ->
    let%bind bs = Checked.unpack ~length:Field.size_in_bits x >>| List.rev in
    let%map () =
      lt_bitstring_value_msb bs field_size_bits_msb >>= Boolean.Assert.is_true
    in
    bs

(* floor(size of field / y) *)
let strength (y : Packed.var) =
  let open Tick in
  let open Let_syntax in
  let%bind z =
    exists Var_spec.field
      As_prover.(map (read_var y) ~f:strength_unchecked)
  in
  let%bind () =
    let%bind k = num_bits_upper_bound z in
    let%bind m =
      Checked.unpack ~length:size_in_bits_size_in_bits
        Cvar.(sub (constant Field.(of_int size_in_bits)) k)
    in
    assert_num_bits_upper_bound m y
  in
  let%bind zy = Checked.mul z y in
  let%bind zy_bits = bits_msb zy in
  let%bind zy_plus_y_bits = bits_msb Cvar.Infix.(zy + y) in
  let%map () =
    lt_bitstrings_msb zy_plus_y_bits zy_bits >>= Boolean.Assert.is_true 
  in
  z
;;

(* TODO
let strength (target : Packed.var) =
  let open Tick in
  let open Let_syntax in
  let%bind z = exists Var_spec.field As_prover.(map (read_var target) ~f:strength_unchecked) in
  (* numbits(z) + numbits(target) = Field.size_in_bits or Field.size_in_bits - 1 or ?
     and 
     (z + 1) * target < target
  *)
  (* num_bits unpacks. This is wasteful since target gets unpacked elsewhere *)
  let%bind target_bit_size = Util.num_bits_upper_bound target in
  let%bind z_bit_size = Util.num_bits_upper_bound z in
  let b = Cvar.Infix.(target_bit_size + z_bit_size) in
  let%bind () =
    assert_mem b
      [ Cvar.constant Field.(of_int size_in_bits)
      ; Cvar.constant Field.(of_int (size_in_bits - 1))
      ]
  in
  let%map () =
    let%bind prod = Checked.mul Cvar.(Infix.(z + constant Field.one)) target in
    let%bind { less } = Util.compare ~bit_length:Field.size_in_bits prod target in
    Boolean.Assert.is_true less
  in
  z
;;
*)
