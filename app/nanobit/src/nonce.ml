open Core_kernel
open Nanobit_base

module Stable = struct
  module V1 = struct
    type t = Int64.t
    [@@deriving bin_io]
  end
end

include Stable.V1

let succ = Int64.succ

let zero = Int64.zero

let random () = Random.int64 Int64.max_value

include Bits.Snarkable.Int64(Snark_params.Tick)

module Bits = Bits.Int64
