open Core_kernel

module Make
  : functor
    (Field : Camlsnark.Field_intf.S)
    (Curve : Camlsnark.Curves.Edwards.S with type field := Field.t) -> sig
  module Digest : sig
    type t [@@deriving bin_io]

    module Snarkable : functor (Impl : Snark_intf.S) ->
      Impl.Snarkable.Bits.S
  end

  module Params : sig
    type t = Curve.t array

    val random : max_input_length:int -> t

    val t : t
  end

  module State : sig
    type t

    val create : Params.t ->  t

    val update : t -> Bigstring.t -> unit

    val digest : t -> Digest.t
  end
end
