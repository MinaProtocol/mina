open Core_kernel

type t = private Bigstring.t
[@@deriving bin_io]

module Snarkable : functor (Impl : Snark_intf.S) ->
  Impl.Snarkable.Bits.S
