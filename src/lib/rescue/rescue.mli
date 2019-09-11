module Params : sig
  type 'a t [@@deriving bin_io]

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val create : m:int -> random_elt:(unit -> 'a) -> 'a t
end

module Make (Inputs : Inputs.S) : sig
  open Inputs

  val hash : Field.t Params.t -> Field.t array array -> Field.t
end
