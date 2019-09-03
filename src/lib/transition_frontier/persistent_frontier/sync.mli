open Async_kernel

module Make : functor (Inputs : Intf.Inputs_with_db_intf) -> sig
  open Inputs

  type t

  val create :
       logger:Logger.t
    -> base_hash:Frontier.Hash.t
    -> persistent_frontier:Db.t
    -> t

  val notify :
       t
    -> diffs:Frontier.Diff.Lite.E.t list
    -> hash_transition:Frontier.Hash.transition
    -> unit

  val close :
       t
    -> unit Deferred.t
end
