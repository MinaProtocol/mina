open Async_kernel
open Core_kernel
open Pipe_lib

module type S = sig
  type ledger_proof

  type transaction_snark_statement

  type transaction_snark_work_statement

  type transaction_snark_work_checked

  type transition_frontier

  type transaction_snark_work_info

  module Resource_pool : sig
    include
      Intf.Snark_resource_pool_intf
      with type ledger_proof := ledger_proof
       and type work := transaction_snark_work_statement
       and type transition_frontier := transition_frontier
       and type work_info := transaction_snark_work_info

    val remove_solved_work : t -> transaction_snark_work_statement -> unit

    module Diff :
      Intf.Snark_pool_diff_intf
      with type ledger_proof := ledger_proof
       and type work := transaction_snark_work_statement
       and type resource_pool := t
  end

  include
    Intf.Network_pool_base_intf
    with type resource_pool := Resource_pool.t
     and type resource_pool_diff := Resource_pool.Diff.t
     and type transition_frontier := transition_frontier

  val get_completed_work :
       t
    -> transaction_snark_work_statement
    -> transaction_snark_work_checked option

  val load :
       logger:Logger.t
    -> pids:Child_processes.Termination.t
    -> trust_system:Trust_system.t
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
       , ledger_proof )
       Snark_work_lib.Work.Result.t
    -> unit Deferred.t
end

module type Transition_frontier_intf = sig
  type work

  type t

  module Extensions : sig
    module Work : sig
      type t = work [@@deriving sexp]

      module Stable : sig
        module V1 : sig
          type nonrec t = t [@@deriving sexp, bin_io]

          include Hashable.S_binable with type t := t
        end
      end

      include Hashable.S with type t := t
    end
  end

  val snark_pool_refcount_pipe :
    t -> (int * int Extensions.Work.Table.t) Pipe_lib.Broadcast_pipe.Reader.t
end

module Make
    (Transition_frontier : Transition_frontier_intf
                           with type work := Transaction_snark_work.Statement.t) :
  S
  with type transaction_snark_statement := Transaction_snark.Statement.t
   and type transaction_snark_work_statement :=
              Transaction_snark_work.Statement.t
   and type transaction_snark_work_checked := Transaction_snark_work.Checked.t
   and type transition_frontier := Transition_frontier.t
   and type ledger_proof := Ledger_proof.t
   and type transaction_snark_work_info := Transaction_snark_work.Info.t

include
  S
  with type transaction_snark_statement := Transaction_snark.Statement.t
   and type transaction_snark_work_statement :=
              Transaction_snark_work.Statement.t
   and type transaction_snark_work_checked := Transaction_snark_work.Checked.t
   and type transition_frontier := Transition_frontier.t
   and type ledger_proof := Ledger_proof.t
   and type transaction_snark_work_info := Transaction_snark_work.Info.t
