open Protocols.Coda_transition_frontier
open Coda_base
module Inputs = Inputs
module Processor = Processor
module Validator = Validator

module Make (Inputs : Inputs.S) :
  Transition_handler_intf
  with type time := Inputs.Time.t
   and type time_controller := Inputs.Time.Controller.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type state_hash := State_hash.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  module Unprocessed_transition_cache =
    Unprocessed_transition_cache.Make (Inputs)

  module Full_inputs = struct
    include Inputs
    module Unprocessed_transition_cache = Unprocessed_transition_cache
  end

  module Processor = Processor.Make (Full_inputs)
  module Validator = Validator.Make (Full_inputs)
end
