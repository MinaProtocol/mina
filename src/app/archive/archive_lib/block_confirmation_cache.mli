open Coda_base

(** To reduce the amount of database queries for block confirmations, we have a
    cache representing the transition frontier. The cache is a mapping of
    state_hashes to their parent state_hash and number of block confirmations *)
type t

type block_data = {block_height: int; parent: State_hash.t option}

val create : (State_hash.t * block_data) list -> t

(** When we make an update to the cache, we will return all the keys that have
    updated by the cache and their new values *)
val update :
     t
  -> State_hash.t * [`Parent of State_hash.t]
  -> int
  -> (State_hash.t * block_data) list
