open Async_kernel
open Frontier_base

type t

val create : logger:Logger.t -> base_hash:Frontier_hash.t -> db:Database.t -> t

val notify :
     t
  -> diffs:Diff.Lite.E.t list
  -> hash_transition:Frontier_hash.transition
  -> unit

val close : t -> unit Deferred.t
