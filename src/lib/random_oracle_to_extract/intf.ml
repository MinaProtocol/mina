module Input = Random_oracle_input

module type Field = sig
  include Sponge.Intf.Field

  type boolean

  val unpack : t -> boolean list

  val size : Bigint.t

  val size_in_bits : int

  val project : bool list -> t

  val of_string : string -> t
end

module type Config = sig
  type boolean

  module Field : Field with type boolean := boolean

  include Sponge.Intf.Inputs.Poseidon with module Field := Field
end

module type S = sig
  module State : sig
    type 'a t [@@deriving eq, sexp, compare]

    val map : 'a t -> f:('a -> 'b) -> 'b t

    val map2 : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t (* TODO: delete? *)
  end

  type field

  type field_constant

  type boolean

  module Digest : sig
    type t = field

    val to_bits : ?length:int -> t -> boolean list
  end

  val initial_state : field State.t

  val update : state:field State.t -> field array -> field State.t

  val digest : field State.t -> Digest.t

  val hash : ?init:field_constant State.t -> field array -> Digest.t

  val pack_input : (field, bool) Input.t -> field array

  val salt : string -> field State.t
end
