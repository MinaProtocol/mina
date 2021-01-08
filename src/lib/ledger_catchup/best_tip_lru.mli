open Mina_base
open Mina_transition

type elt =
  ( External_transition.Initial_validated.t
  , State_body_hash.t list * External_transition.t )
  Proof_carrying_data.t

val add : elt -> unit

val get : State_hash.t -> elt option
