open Coda_base
open Frontier_base

include Frontier_intf.S

val create :
     logger:Logger.t
  -> root_data:Root_data.t
  -> root_ledger:Ledger.Db.t
  -> base_hash:Frontier_hash.t
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> max_length:int
  -> t

val close : t -> unit

val root_data : t -> Root_data.t

val set_hash_unsafe : t -> [`I_promise_this_is_safe of Frontier_hash.t] -> unit

val hash : t -> Frontier_hash.t

val calculate_diffs : t -> Breadcrumb.t -> Diff.Full.E.t list

val apply_diffs :
  t -> Diff.Full.E.t list -> [`New_root of Root_identifier.t option]
