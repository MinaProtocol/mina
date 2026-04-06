open Core
open Network_peer

type t

val create : capacity:int * [ `Per of Time_float.Span.t ] -> t

val add :
     t
  -> Envelope.Sender.t
  -> now:Time_float.t
  -> score:int
  -> [ `Within_capacity | `Capacity_exceeded ]

val next_expires : t -> Envelope.Sender.t -> Time_float.t

val summary : t -> Yojson.Safe.t
