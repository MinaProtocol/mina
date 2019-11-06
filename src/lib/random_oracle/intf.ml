module type S = sig
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

  val pack_input : (field, bool) Input.t -> field array
end

module Full (Field : sig
  type t
end) =
struct
  module type S = sig
    include
      S
      with type field := Field.t
       and type field_constant := Field.t
       and type bool := bool

    val salt : string -> Field.t State.t

    module Checked :
      S
      with type field := Field.t Snarky.Cvar.t
       and type field_constant := Field.t
       and type bool := Field.t Snarky.Cvar.t Snarky.Boolean.t
       and module State := State
  end
end
