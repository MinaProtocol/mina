open Core_kernel

module Digest : sig
  type t [@@deriving bin_io]

  module Snarkable : functor (Impl : Snark_intf.S) ->
    Impl.Snarkable.Bits.S
end

module Curve
  : Camlsnark.Curves.Complete_intf_basic
    with type field := Snark_params.Main.Field.t

module Params : sig
  type t = Curve.t array

  val random : max_input_length:int -> t
end

module State : sig
  type t

  val create : Params.t ->  t

  val update : t -> Bigstring.t -> unit

  val digest : t -> Digest.t
end
