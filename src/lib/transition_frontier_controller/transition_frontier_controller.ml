open Core_kernel
open Protocols.Coda_pow
open Coda_base

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus_mechanism_intf
    with type protocol_state_hash := State_hash.t

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Merkle_hash.t

  module Transition_frontier :
    Transition_frontier_intf
    with type external_transition := Consensus_mechanism.External_transition.t
     and type state_hash := State_hash.t
     and type merkle_ledger := Ledger.t

  module Transition_handler :
    Transition_handler_intf
    with type external_transition := Consensus_mechanism.External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t

  module Catchup :
    Catchup_intf
    with type external_transition := Consensus_mechanism.External_transition.t
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t

  module Sync_handler :
    Sync_handler_intf
    with type addr := Merkle_address.t
     and type hash := Merkle_hash.t
     and type syncable_ledger := Syncable_ledger.t
     and type syncable_ledger_query := Syncable_ledger.query
     and type syncable_ledger_answer := Syncable_ledger.answer
     and type transition_frontier := Transition_frontier.t
end

module Make (Inputs : Inputs_intf) :
  Transition_frontier_controller_intf
  with type external_transition :=
              Inputs.Consensus_mechanism.External_transition.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer = struct
  open Inputs
  open Consensus_mechanism

  let run ~genesis_transition ~transition_reader ~sync_query_reader ~sync_answer_writer =
    let valid_transition_reader, valid_transition_writer =
      Linear_pipe.create ()
    in
    let catchup_job_reader, catchup_job_writer = Linear_pipe.create () in
    (* TODO: initialize transition frontier from disk *)
    let frontier =
      Transition_frontier.create
        ~root:(
          With_hash.of_data
            genesis_transition
            ~hash_data:(Fn.compose
              Protocol_state.hash
              External_transition.protocol_state))
        ~ledger:Genesis_ledger.t
    in
    Transition_handler.Validator.run ~transition_reader ~valid_transition_writer ;
    Transition_handler.Processor.run ~valid_transition_reader ~catchup_job_writer ~frontier ;
    Catchup.run ~catchup_job_reader ~frontier ;
    Sync_handler.run ~sync_query_reader ~sync_answer_writer ~frontier
end
