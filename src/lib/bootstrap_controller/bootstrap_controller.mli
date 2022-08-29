open Async_kernel
open Pipe_lib
open Network_peer

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val verifier : Verifier.t
end

type Structured_log_events.t += Bootstrap_complete [@@deriving register_event]

val run :
     context:(module CONTEXT)
  -> trust_system:Trust_system.t
  -> network:Mina_networking.t
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> transition_reader:
       ( [ `Block of Mina_block.initial_valid_block Envelope.Incoming.t ]
       * [ `Valid_cb of Mina_net2.Validation_callback.t option ] )
       Strict_pipe.Reader.t
  -> best_seen_transition:
       Mina_block.initial_valid_block Envelope.Incoming.t option
  -> persistent_root:Transition_frontier.Persistent_root.t
  -> persistent_frontier:Transition_frontier.Persistent_frontier.t
  -> initial_root_transition:Mina_block.Validated.t
  -> catchup_mode:[ `Normal | `Super ]
  -> ( Transition_frontier.t
     * Mina_block.initial_valid_block Envelope.Incoming.t list )
     Deferred.t
