open Core_kernel
open Snark_bits
open Pedersen_types

module type S = sig
  type curve

  type ('s, 'b) fold = init:'s -> f:('s -> 'b -> 's) -> 's

  module Digest : sig
    type t [@@deriving bin_io, sexp, eq]

    val size_in_bits : int

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable (Impl : Snark_intf.S) :
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Field.Checked.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Bits_params : sig
    type t = curve array

    val random : max_input_length:int -> t
  end

  module Bits_state : sig
    type t = {bits_consumed: int; acc: curve; params: Bits_params.t}

    val create : ?bits_consumed:int -> ?init:curve -> Bits_params.t -> t

    val update_bigstring : t -> Bigstring.t -> t

    val update_string : t -> string -> t

    val update_bit_fold : t -> ((curve * int), bool) fold -> t

    val update_iter : t -> (f:(bool -> unit) -> unit) -> t

    val digest : t -> Digest.t

    val salt : Bits_params.t -> string -> t
  end

  val hash_bit_fold : Bits_state.t -> ((curve * int), bool) fold -> Bits_state.t

  val digest_bit_fold : Bits_state.t -> ((curve * int), bool) fold -> Digest.t


  module Params : sig
    type t = curve Quadruple.t array

    val of_curve : curve -> curve Quadruple.t
(*
    val random : max_input_length:int -> t
*)
  end

  module State : sig
    type t = {triples_consumed: int; acc: curve; params: Params.t}

    val create : ?triples_consumed:int -> ?init:curve -> Params.t -> t

    val update_bigstring : t -> Bigstring.t -> t

    val update_string : t -> string -> t

    val update_fold : t -> ((curve * int), bool Triple.t) fold -> t
(*
    val update_iter : t -> (f:(bool -> unit) -> unit) -> t
*)
    val digest : t -> Digest.t
(*  
    val salt : Triple_params.t -> string -> t
*)
  end

  val hash_fold : State.t -> ((curve * int), bool Triple.t) fold -> State.t

  val digest_fold : State.t -> ((curve * int), bool Triple.t) fold -> Digest.t

end

module Make (Field : sig
  include Snarky.Field_intf.S

  include Sexpable.S with type t := t
end)
(Bigint : Snarky.Bigint_intf.Extended with type field := Field.t)
(Curve : Snarky.Curves.Edwards.Basic.S with type field := Field.t) :
  S with type curve := Curve.t and type Digest.t = Field.t
