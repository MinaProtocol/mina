open Mina_base

type elt =
  ( State_hash.t
  , State_body_hash.t list * Mina_block.Header.t )
  Proof_carrying_data.t

val add : elt -> unit

val get : State_hash.t -> elt option
