open Async_kernel
open Pipe_lib

module type S = sig
  type transition_frontier

  module Resource_pool : sig
    include
      Intf.Snark_resource_pool_intf
      with type ledger_proof := Ledger_proof.t
       and type work := Transaction_snark_work.Statement.t
       and type transition_frontier := transition_frontier
       and type work_info := Transaction_snark_work.Info.t

    val remove_solved_work : t -> Transaction_snark_work.Statement.t -> unit

    module Diff :
      Intf.Snark_pool_diff_intf
      with type ledger_proof := Ledger_proof.t
       and type work := Transaction_snark_work.Statement.t
       and type resource_pool := t
  end

  module For_tests : sig
    val get_rebroadcastable :
         Resource_pool.t
      -> is_expired:(Core.Time.t -> [`Expired | `Ok])
      -> Resource_pool.Diff.t list
  end

  include
    Intf.Network_pool_base_intf
    with type resource_pool := Resource_pool.t
     and type resource_pool_diff := Resource_pool.Diff.t
     and type transition_frontier := transition_frontier
     and type config := Resource_pool.Config.t

  val get_completed_work :
       t
    -> Transaction_snark_work.Statement.t
    -> Transaction_snark_work.Checked.t option

  val load :
       config:Resource_pool.Config.t
    -> logger:Logger.t
    -> disk_location:string
    -> incoming_diffs:Resource_pool.Diff.t Envelope.Incoming.t
                      Linear_pipe.Reader.t
    -> frontier_broadcast_pipe:transition_frontier option
                               Broadcast_pipe.Reader.t
    -> t Deferred.t

  val add_completed_work :
       t
    -> ( ('a, 'b, 'c) Snark_work_lib.Work.Single.Spec.t
         Snark_work_lib.Work.Spec.t
       , Ledger_proof.t )
       Snark_work_lib.Work.Result.t
    -> unit Deferred.t
end

module type Transition_frontier_intf = sig
  type t

  val snark_pool_refcount_pipe :
       t
    -> (int * int Transaction_snark_work.Statement.Table.t)
       Pipe_lib.Broadcast_pipe.Reader.t
end

module Make (Transition_frontier : Transition_frontier_intf) :
  S with type transition_frontier := Transition_frontier.t

include S with type transition_frontier := Transition_frontier.t
