open Core_kernel
module Input = Random_oracle_input

module State = struct
  include Array

  let map2 = map2_exn
end

module type S = sig
  module State : sig
    type _ t
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

  val pack_input : (field, boolean) Input.t -> field array
end
