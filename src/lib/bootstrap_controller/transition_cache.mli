open Coda_base
open Coda_transition

type t

val create : unit -> t

val add :
     t
  -> parent:State_hash.t
  -> External_transition.Initial_validated.t Envelope.Incoming.t
  -> unit

val data :
  t -> External_transition.Initial_validated.t Envelope.Incoming.t list
