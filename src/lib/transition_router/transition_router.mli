module type Inputs_intf = sig
  include Coda_intf.Inputs_intf

  module Network : sig
    type t
  end

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
     and type 'a transaction_snark_work_statement_table :=
       'a Transaction_snark_work.Statement.Table.t

  module Transition_frontier_controller :
    Coda_intf.Transition_frontier_controller_intf
    with type external_transition_validated := External_transition.Validated.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type transition_frontier := Transition_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type network := Network.t
     and type verifier := Verifier.t

  module Bootstrap_controller :
    Coda_intf.Bootstrap_controller_intf
    with type network := Network.t
     and type verifier := Verifier.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Transition_router_intf
    with type verifier := Inputs.Verifier.t
     and type external_transition := Inputs.External_transition.t
     and type external_transition_validated := Inputs.External_transition.Validated.t
     and type transition_frontier := Inputs.Transition_frontier.t
     and type transition_frontier_persistent_root := Inputs.Transition_frontier.Persistent_root.t
     and type breadcrumb := Inputs.Transition_frontier.Breadcrumb.t
     and type network := Inputs.Network.t
