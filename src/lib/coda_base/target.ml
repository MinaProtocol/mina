open Core_kernel
open Snark_params
open Snark_bits

module Stable = struct
  module V1 = struct
    type t = Tick.Field.t [@@deriving bin_io, sexp, eq, compare]
  end
end

include Stable.V1
module Field = Tick.Field
module Bigint = Tick_backend.Bigint.R

let bit_length = Snark_params.target_bit_length

let max_bigint =
  Tick.Bigint.of_bignum_bigint
    Bignum_bigint.(pow (of_int 2) (of_int bit_length) - one)

let max = Bigint.to_field max_bigint

let constant = Tick.Field.Checked.constant

let of_field x =
  assert (Bigint.compare (Bigint.of_field x) max_bigint <= 0) ;
  x

let to_bigint x = Tick.Bigint.to_bignum_bigint (Bigint.of_field x)

let of_bigint n =
  let x = Tick.Bigint.of_bignum_bigint n in
  assert (Bigint.compare x max_bigint <= 0) ;
  Bigint.to_field x

let assert_mem x xs =
  let open Tick in
  let open Let_syntax in
  let rec go acc = function
    | [] -> Boolean.Assert.any acc
    | y :: ys ->
        let%bind e = Field.Checked.equal x y in
        go (e :: acc) ys
  in
  go [] xs

(* TODO: Use a "dual" variable to ensure the bit_length constraint is actually always
   enforced. *)
include Bits.Snarkable.Small
          (Tick)
          (struct
            let bit_length = bit_length
          end)

module Bits =
  Bits.Small (Tick.Field) (Tick.Bigint)
    (struct
      let bit_length = bit_length
    end)

open Tick
open Let_syntax

let var_to_unpacked (x : Field.Checked.t) =
  Field.Checked.unpack ~length:bit_length x
