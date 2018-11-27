open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Pipe_lib

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus_mechanism_intf

  module Transition_frontier : Transition_frontier_intf
end

module Make (Inputs : Inputs_intf) :
  Catchup_intf
  with type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type state_hash := Coda_base.State_hash.t = struct
  let run ~frontier:_ ~catchup_job_reader =
    don't_wait_for
      (Strict_pipe.Reader.iter catchup_job_reader ~f:(fun _ ->
           failwith "Intentionally unimplemented catchup" ))
end
