module Inputs = Inputs

module Components = struct
  module Processor = Processor
  module Catchup_scheduler = Catchup_scheduler
  module Validator = Validator
end

module Make (Inputs : Inputs.S) :
  Coda_intf.Transition_handler_intf
  with type verifier := Inputs.Verifier.t
   and type external_transition_with_initial_validation :=
              Inputs.External_transition.with_initial_validation
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  module Unprocessed_transition_cache =
    Unprocessed_transition_cache.Make (Inputs)

  module Full_inputs = struct
    include Inputs
    module Unprocessed_transition_cache = Unprocessed_transition_cache
  end

  module Breadcrumb_builder = Breadcrumb_builder.Make (Full_inputs)
  module Processor = Processor.Make (Full_inputs)
  module Validator = Validator.Make (Full_inputs)
end

include Make (struct
  open Coda_transition
  module Verifier = Verifier
  module Ledger_proof = Ledger_proof
  module Staged_ledger_diff = Staged_ledger_diff
  module Transaction_snark_work = Transaction_snark_work
  module External_transition = External_transition
  module Internal_transition = Internal_transition
  module Staged_ledger = Staged_ledger
  module Transition_frontier = Transition_frontier
end)
