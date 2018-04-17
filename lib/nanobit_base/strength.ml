open Core_kernel
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

let field_var_to_unpacked (x : Tick.Cvar.t) = Tick.Checked.unpack ~length:bit_length x

include Bits.Snarkable.Small(Tick)(struct let bit_length = bit_length end)

module Bits = Bits.Make_field(Tick.Field)(Tick.Bigint)

let packed_to_number t = 
  let%map unpacked = unpack_var t in
  Tick.Number.of_bits (Unpacked.var_to_bits unpacked)

let packed_of_number num =
  let%map unpacked = field_var_to_unpacked (Number.to_var num) in
  pack_var unpacked

let compare x y =
  Tick.Bigint.(compare (of_field x) (of_field y))

let (<) x y = compare x y < 0
let (>) x y = compare x y > 0
let (=) x y = compare x y = 0
let (>=) x y = not (x < y)
let (<=) x y = not (x > y)
