module type S = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier : Coda_intf.Transition_frontier_intf

  (*    with type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * Coda_base.State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition*)

  module Unprocessed_transition_cache :
    Coda_intf.Unprocessed_transition_cache_intf

  module Transition_handler_validator :
    Coda_intf.Transition_handler_validator_intf
    with type unprocessed_transition_cache := Unprocessed_transition_cache.t
     and type transition_frontier := Transition_frontier.t

  module Breadcrumb_builder :
    Coda_intf.Breadcrumb_builder_intf
    with type transition_frontier := Transition_frontier.t
     and type transition_frontier_breadcrumb :=
                Transition_frontier.Breadcrumb.t

  module Network : Coda_intf.Network_intf
end
