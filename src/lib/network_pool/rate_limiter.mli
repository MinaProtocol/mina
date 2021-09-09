open Core
open Network_peer

type t

val create : capacity:int * [`Per of Time.Span.t] -> t

val add :
     t
  -> Envelope.Sender.t
  -> now:Time.t
  -> score:int
  -> [`Within_capacity | `Capacity_exceeded]

val summary : t -> Yojson.Safe.t
