open Mina_base
open Network_peer

type initial_valid_block_or_header =
  | Block of Mina_block.initial_valid_block
  | Header of Mina_block.initial_valid_header

val header_with_hash :
  initial_valid_block_or_header -> Mina_block.Header.with_hash

type element =
  initial_valid_block_or_header Envelope.Incoming.t
  * Mina_net2.Validation_callback.t option

type t

val create : unit -> t

val add : t -> parent:State_hash.t -> element -> unit

val data : t -> element list
