open Async_kernel
open Coda_base

module Make : functor (Inputs : Intf.Main_inputs_intf) -> sig
  open Inputs

  type t

  val create :
       ?directory_name:string
    -> logger:Logger.t
    -> base_hash:Incremental_hash.t
    -> t Deferred.t

  val notify :
       t
    -> diff:Diff.Lite.E.t
    -> hash:Incremental_hash.t
    -> unit

  val load_frontier :
       directory_name:string
    -> logger:Logger.t
    -> verifier:Verifier.t
    -> trust_system:Trust_system.t
    -> root_snarked_ledger:Ledger.Db.t
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> Transition_frontier_base.t Deferred.t
end
