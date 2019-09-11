module Params : sig
  type 'a t = {mds: 'a array array; round_constants: 'a array array}
  [@@deriving bin_io]

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val create : m:int -> random_elt:(unit -> 'a) -> 'a t
end

module Make (Inputs : Inputs.S) : sig
  open Inputs

  val hash : Field.t Params.t -> Field.t array -> Field.t
end
