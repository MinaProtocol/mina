open Coda_base

module State : Intf.State_intf

module type Selection_method_intf =
  Intf.Selection_method_intf
  with type snark_pool := Network_pool.Snark_pool.t
   and type staged_ledger := Staged_ledger.t
   and type work :=
              ( Transaction.t Transaction_protocol_state.t
              , Transaction_witness.t
              , Ledger_proof.t )
              Snark_work_lib.Work.Single.Spec.t
   and module State := State

module Selection_methods : sig
  module Random : Selection_method_intf

  module Sequence : Selection_method_intf
end
