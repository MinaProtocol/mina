(** This module provides the implementation for actively "syncing" the
 *  persistent frontier database. A [Sync] job can be created, and can
 *  then be sent diffs to accumulate and apply to the database in chunks
 *  (using the [Diff_buffer]).
 *)

open Async_kernel
open Frontier_base

type t

val create :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> logger:Logger.t
  -> time_controller:Block_time.Controller.t
  -> db:Database.t
  -> dequeue_snarked_ledger:(unit -> unit)
  -> t

val notify : t -> diffs:Diff.Lite.E.t list -> unit

val close : t -> unit Deferred.t

val buffer : t -> Diff.Lite.E.t list
