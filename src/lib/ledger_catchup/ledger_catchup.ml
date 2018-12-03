open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Pipe_lib

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus_mechanism_intf

  module Transition_frontier : Transition_frontier_intf

  module External_transition :
    External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value
     and type ledger_builder_diff := Consensus_mechanism.ledger_builder_diff
     and type protocol_state_proof := Consensus_mechanism.protocol_state_proof
end

module Make (Inputs : Inputs_intf) :
  Catchup_intf
  with type external_transition := Inputs.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type state_hash := Coda_base.State_hash.t = struct
  let run ~frontier:_ ~catchup_job_reader ~catchup_breadcrumbs_writer:_ =
    don't_wait_for
      (Strict_pipe.Reader.iter catchup_job_reader ~f:(fun _ ->
           failwith "Intentionally unimplemented catchup" ))
end
