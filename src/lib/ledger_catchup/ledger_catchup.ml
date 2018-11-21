open Core_kernel
open Async_kernel
open Protocols.Coda_pow

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus_mechanism_intf

  module Transition_frontier : Transition_frontier_intf
end

module Make (Inputs : Inputs_intf) :
  Catchup_intf
  with type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t = struct
  let run ~catchup_job_reader _transition_frontier =
    don't_wait_for
      (Linear_pipe.iter catchup_job_reader ~f:(fun _ ->
           failwith "Intentionally unimplemented catchup" ))
end
