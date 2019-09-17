module type S = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier : Coda_intf.Transition_frontier_intf

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
