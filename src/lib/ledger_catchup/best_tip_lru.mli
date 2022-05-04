open Mina_base
open Mina_transition

type elt =
  ( Mina_block.initial_valid_block
  , State_body_hash.t list * Mina_block.t )
  Proof_carrying_data.t

val add : elt -> unit

val get : State_hash.t -> elt option
