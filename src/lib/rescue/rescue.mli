module Params : sig
  type 'a t = {mds: 'a array array; round_constants: 'a array array}
  [@@deriving bin_io]

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module State : sig
  type 'a t = 'a array

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module Make (Inputs : Inputs.S) : sig
  open Inputs

  val update :
    Field.t Params.t -> Field.t State.t -> Field.t array -> Field.t State.t

  val digest : Field.t State.t -> Field.t

  val hash : Field.t Params.t -> Field.t array -> Field.t
end
