(** This module provides the implementation for actively "syncing" the
 *  persistent frontier database. A [Sync] job can be created, and can
 *  then be sent diffs to accumulate and apply to the databse in chunks
 *  (using the [Diff_buffer]).
 *)

open Async_kernel
open Frontier_base

type t

val create :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> logger:Logger.t
  -> time_controller:Block_time.Controller.t
  -> base_hash:Frontier_hash.t
  -> db:Database.t
  -> t

val notify :
     t
  -> garbage:Coda_base.State_hash.t list
     (* Nodes that have already been garbage collected *)
  -> diffs:Diff.Lite.E.t list
  -> hash_transition:Frontier_hash.transition
  -> unit

val close : t -> unit Deferred.t
