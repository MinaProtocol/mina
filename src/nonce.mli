open Core_kernel

type t = private Bigstring.t
[@@deriving bin_io]

val zero : t

module Snarkable : functor (Impl : Snark_intf.S) ->
  Impl.Snarkable.Bits.S

