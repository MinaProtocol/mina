module State :
  Intf.State_intf with type transition_frontier := Transition_frontier.t

type work =
  (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t

type snark_pool = Network_pool.Snark_pool.t

module type Selection_method_intf =
  Intf.Selection_method_intf
    with type snark_pool := snark_pool
     and type staged_ledger := Staged_ledger.t
     and type work := work
     and type transition_frontier := Transition_frontier.t
     and module State := State

module Selection_methods : sig
  module Random : Selection_method_intf

  module Sequence : Selection_method_intf

  module Random_offset : Selection_method_intf
end

(** remove the specified work from seen jobs *)
val remove : State.t -> work One_or_two.t -> unit

(** Seen/Unseen jobs that are not in the snark pool yet *)
val pending_work_statements :
     snark_pool:snark_pool
  -> fee_opt:Currency.Fee.t option
  -> State.t
  -> Transaction_snark.Statement.t One_or_two.t list
