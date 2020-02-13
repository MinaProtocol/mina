open Async_kernel
open Pipe_lib

module type S = sig
  module Resource_pool : sig
    include
      Intf.Snark_resource_pool_intf
      with type ledger_proof := Ledger_proof.t
       and type work := Transaction_snark_work.Statement.t
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
     and type config := Resource_pool.Config.t

  val get_completed_work :
       t
    -> Transaction_snark_work.Statement.t
    -> Transaction_snark_work.Checked.t option

  val add_completed_work :
       t
    -> ( ('a, 'b, 'c) Snark_work_lib.Work.Single.Spec.t
         Snark_work_lib.Work.Spec.t
       , Ledger_proof.t )
       Snark_work_lib.Work.Result.t
    -> unit Deferred.t
end

module Make (Transition_frontier : sig
  type t

  val snark_pool_refcount_pipe :
    Transaction_snark_work.Statement.Stable.V1.t Broadcast_pipe.Reader.t
end) : S
