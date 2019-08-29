open Coda_transition
module Inputs = Inputs

module Components : sig
  module Processor = Processor
  module Catchup_scheduler = Catchup_scheduler
  module Validator = Validator
end

module Make (Inputs : Inputs.S) :
  Coda_intf.Transition_handler_intf
  with type verifier := Verifier.t
   and type external_transition_with_initial_validation :=
              External_transition.with_initial_validation
   and type external_transition_validated := External_transition.Validated.t
   and type staged_ledger := Staged_ledger.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t

include
  Coda_intf.Transition_handler_intf
  with type verifier := Verifier.t
   and type external_transition_with_initial_validation :=
              External_transition.with_initial_validation
   and type external_transition_validated := External_transition.Validated.t
   and type staged_ledger := Staged_ledger.t
   and type transition_frontier := Transition_frontier.t
   and type transition_frontier_breadcrumb := Transition_frontier.Breadcrumb.t
