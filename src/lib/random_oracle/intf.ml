module Input = Random_oracle_input

module type S = sig
  type input

  module State : sig
    type _ t
  end

  type field

  type field_constant

  type bool

  module Digest : sig
    type t = field

    val to_bits : ?length:int -> t -> bool list
  end

  val initial_state : field State.t

  val update : state:field State.t -> field array -> field State.t

  val digest : field State.t -> Digest.t

  val hash : ?init:field_constant State.t -> field array -> Digest.t

  val pack_input : input -> field array
end
