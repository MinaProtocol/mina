open Core_kernel

module type S = sig
  type curve

  type fold = init:(curve * int) -> f:((curve * int) -> bool -> (curve * int)) -> curve * int

  module Digest : sig
    type t [@@deriving bin_io, sexp]

    val (=) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable : functor (Impl : Snark_intf.S) ->
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Cvar.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Params : sig
    type t = curve array

    val random : max_input_length:int -> t
  end

  module State : sig
    type t

    val create : Params.t ->  t

    val update_bigstring : t -> Bigstring.t -> t

    val update_fold
      : t -> fold -> t

    val update_iter
      : t
      -> (f:(bool -> unit) -> unit)
      -> t

    val digest : t -> Digest.t
  end

  val hash_fold : Params.t -> fold -> Digest.t
end

module Make
  : functor
    (Field : sig include Snarky.Field_intf.S include Sexpable.S with type t := t end)
    (Bigint : Snarky.Bigint_intf.Extended with type field := Field.t)
    (Curve : Snarky.Curves.Edwards.Basic.S with type field := Field.t) ->
    S with type curve := Curve.t
       and type Digest.t = Field.t
