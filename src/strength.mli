open Core_kernel

type t = private Bigstring.t
[@@deriving bin_io, compare]

val zero : t

val increment : t -> t

module Snarkable : functor (Impl : Snark_intf.S) ->
  Impl.Snarkable.Bits.S
