open Mina_base
open Network_peer

type t

val create : unit -> t

val add :
     t
  -> parent:State_hash.t
  -> Mina_block.initial_valid_block Envelope.Incoming.t
  -> unit

val data : t -> Mina_block.initial_valid_block Envelope.Incoming.t list
