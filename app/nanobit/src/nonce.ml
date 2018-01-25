open Core_kernel
open Nanobit_base

type t = Int64.t
[@@deriving bin_io]

let succ = Int64.succ

let zero = Int64.zero

let random () = Random.int64 Int64.max_value

include Bits.Snarkable.Int64(Snark_params.Tick)

module Bits = Bits.Int64
