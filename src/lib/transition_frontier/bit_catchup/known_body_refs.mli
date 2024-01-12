open Mina_base

type t

val create : unit -> t

val remove_reference :
     t
  -> logger:Logger.t
  -> block_storage:Lmdb_storage.Block.t
  -> Consensus.Body_reference.t
  -> State_hash.t
  -> [> `Body_present of bool ] * [> `Removal_triggered of bool ]

val prune :
     t
  -> logger:Logger.t
  -> block_storage:Lmdb_storage.Block.t
  -> header_storage:Lmdb_storage.Header.t
  -> ?body_ref:Consensus.Body_reference.t
  -> State_hash.t
  -> [> `Removal_triggered of Consensus.Body_reference.t option ]

val on_block_body_removed :
     t
  -> header_storage:Lmdb_storage.Header.t
  -> Consensus.Body_reference.t list
  -> unit

val handle_broken :
     logger:Logger.t
  -> mark_invalid:(State_hash.t -> unit)
  -> t
  -> Consensus.Body_reference.t
  -> unit

val state_hashes : t -> Consensus.Body_reference.t -> State_hash.t list option

val add_new :
     ?no_log_on_invalid:bool
  -> logger:Logger.t
  -> t
  -> Consensus.Body_reference.t
  -> State_hash.t
  -> unit
