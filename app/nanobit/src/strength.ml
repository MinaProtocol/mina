open Core_kernel
open Nanobit_base
open Snark_params

type t = Tick.Field.t
[@@deriving bin_io, sexp]

let zero = Tick.Field.zero

include Bits.Snarkable.Field(Tick)

module Bits = Bits.Make_field(Tick.Field)(Tick.Bigint)

let compare x y =
  Tick.Bigint.(compare (of_field x) (of_field y))

let (<) x y = compare x y < 0
let (>) x y = compare x y > 0
let (=) x y = compare x y = 0
let (>=) x y = not (x < y)
let (<=) x y = not (x > y)
