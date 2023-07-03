(** Transition frontier extensions defines the set of extensions which are
 *  attached to an instance of a transition frontier. A transition frontier
 *  extension is an incrementally computed view on the transition frontier's
 *  contents. Extensions synchronously recieve diffs applied to the transition
 *  frontier. Every extension is associated with a broadcast pipe, which allows
 *  outside consumers of extensions to recieve updates a extension's view.
 *  Calling [notify] from this module will update all extensions with the new
 *  transition frontier diffs, waiting for all consumers of each extensions'
 *  broadcast pipes to finish handling any view updates that may occur.
 *)

open Async_kernel
open Pipe_lib
open Frontier_base
module Best_tip_diff = Best_tip_diff
module Root_history = Root_history
module Snark_pool_refcount = Snark_pool_refcount
module New_breadcrumbs = New_breadcrumbs

type t

val create : logger:Logger.t -> Full_frontier.t -> t Deferred.t

val close : t -> unit

val notify :
     t
  -> logger:Logger.t
  -> frontier:Full_frontier.t
  -> diffs_with_mutants:Diff.Full.With_mutant.t list
  -> unit Deferred.t

type ('ext, 'view) access =
  | Root_history : (Root_history.t, Root_history.view) access
  | Snark_pool_refcount
      : (Snark_pool_refcount.t, Snark_pool_refcount.view) access
  | Best_tip_diff : (Best_tip_diff.t, Best_tip_diff.view) access
  | New_breadcrumbs : (New_breadcrumbs.t, New_breadcrumbs.view) access

val get_extension : t -> ('ext, _) access -> 'ext

val get_view_pipe : t -> (_, 'view) access -> 'view Broadcast_pipe.Reader.t
