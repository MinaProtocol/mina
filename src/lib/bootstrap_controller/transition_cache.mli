open Mina_base
open Mina_transition
open Network_peer

type t

val create : unit -> t

val add :
     t
  -> parent:State_hash.t
  -> External_transition.Initial_validated.t Envelope.Incoming.t
  -> unit

val data :
  t -> External_transition.Initial_validated.t Envelope.Incoming.t list
