open Core_kernel
open Util
open Snark_params
open Tick
open Let_syntax

module Stable = struct
  module V1 = struct
    type t = Tick.Field.t
    [@@deriving bin_io, sexp, eq]
  end
end

include Stable.V1

let zero = Tick.Field.zero

let bit_length = Target.bit_length + 1

let () = assert (bit_length < Field.size_in_bits)

let max =
  Bignum.Bigint.(pow (of_int 2) (of_int bit_length) - one)
  |> Bigint.of_bignum_bigint |> Bigint.to_field

let of_field x =
  assert (Field.compare x max <= 0);
  x

let field_var_to_unpacked (x : Tick.Cvar.t) = Tick.Checked.unpack ~length:bit_length x

include Bits.Snarkable.Small(Tick)(struct let bit_length = bit_length end)

module Bits = Bits.Make_field0(Tick.Field)(Tick.Bigint)(struct let bit_length = bit_length end)

let packed_to_number t = 
  let%map unpacked = unpack_var t in
  Tick.Number.of_bits (Unpacked.var_to_bits unpacked)

let packed_of_number num =
  let%map unpacked = field_var_to_unpacked (Number.to_var num) in
  pack_var unpacked

let compare x y =
  Tick.Bigint.(compare (of_field x) (of_field y))

(* TODO: Urgent, this differs from part of the checked function. *)
let of_target_unchecked : Target.t -> t =
  let module Bigint = Tick_curve.Bigint.R in
  let max_bigint = Bigint.of_field (Target.max :> Field.t) in
  fun target ->
    Bigint.div max_bigint (Bigint.of_field (target :> Field.t))
    |> Bigint.to_field
;;

open Tick
open Let_syntax

type _ Snarky.Request.t +=
  | Floor_divide : [ `Two_to_the of int ] * Field.t -> Field.t Snarky.Request.t

let two_to_the i =
  two_to_the i
  |> Bigint.of_bignum_bigint
  |> Bigint.to_field

let floor_divide
      ~numerator:(`Two_to_the (b : int) as numerator)
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

(* floor(two_to_the bit_length / y) *)
let of_target
      (y : Target.Packed.var)
      (y_unpacked : Target.Unpacked.var)
  =
  with_label __LOC__ begin
    if Insecure.strength_calculation
    then
      provide_witness Typ.field
        As_prover.(map (read Target.Packed.typ y) ~f:of_target_unchecked)
    else
      floor_divide ~numerator:(`Two_to_the bit_length)
        (y :> Field.var) (Target.Unpacked.var_to_bits y_unpacked)
  end
;;

let (<) x y = compare x y < 0
let (>) x y = compare x y > 0
let (=) x y = compare x y = 0
let (>=) x y = not (x < y)
let (<=) x y = not (x > y)

let increase (t : t) ~(by : Target.t) : t =
  let incr = of_target_unchecked by in
  of_field (Field.add t incr)

let increase_checked t ~by:(target_packed, target_unpacked) =
  let%map incr = of_target target_packed target_unpacked in
  Cvar.Infix.(t + incr)

