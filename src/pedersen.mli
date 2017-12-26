open Core_kernel

module Digest : sig
  type t [@@deriving bin_io]

  module Snarkable : functor (Impl : Snark_intf.S) ->
    Impl.Snarkable.Bits.S
end

module State : sig
  type t

  val create : unit ->  t

  val update : t -> Bigstring.t -> unit

  val digest : t -> Digest.t
end
