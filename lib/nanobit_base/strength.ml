open Core_kernel
open Snark_params

module Stable = struct
  module V1 = struct
    type t = Tick.Field.t
    [@@deriving bin_io, sexp]
  end
end

include Stable.V1

let zero = Tick.Field.zero

let bit_length = Target.bit_length + 1

include Bits.Snarkable.Small(Tick)(struct let bit_length = bit_length end)

module Bits = Bits.Make_field(Tick.Field)(Tick.Bigint)

let compare x y =
  Tick.Bigint.(compare (of_field x) (of_field y))

let (<) x y = compare x y < 0
let (>) x y = compare x y > 0
let (=) x y = compare x y = 0
let (>=) x y = not (x < y)
let (<=) x y = not (x > y)
