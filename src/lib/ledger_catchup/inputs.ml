module type S = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * Coda_base.State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t

  module Unprocessed_transition_cache :
    Coda_intf.Unprocessed_transition_cache_intf
    with type external_transition_with_initial_validation :=
                External_transition.with_initial_validation

  module Transition_handler_validator :
    Coda_intf.Transition_handler_validator_intf
    with type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type unprocessed_transition_cache := Unprocessed_transition_cache.t
     and type transition_frontier := Transition_frontier.t
     and type staged_ledger := Staged_ledger.t

  module Breadcrumb_builder :
    Coda_intf.Breadcrumb_builder_intf
    with type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type transition_frontier := Transition_frontier.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t
     and type verifier := Verifier.t

  module Network :
    Coda_intf.Network_intf
    with type external_transition := External_transition.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
end
