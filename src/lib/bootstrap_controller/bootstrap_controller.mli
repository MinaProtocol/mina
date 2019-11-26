open Async_kernel
open Coda_base
open Coda_transition
open Pipe_lib

val run :
     logger:Logger.t
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> network:Coda_networking.t
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> transition_reader:( [< `Transition of
                            External_transition.Initial_validated.t
                            Envelope.Incoming.t ]
                       * [< `Time_received of Block_time.t] )
                       Strict_pipe.Reader.t
  -> persistent_root:Transition_frontier.Persistent_root.t
  -> persistent_frontier:Transition_frontier.Persistent_frontier.t
  -> initial_root_transition:External_transition.Validated.t
  -> genesis_protocol_state_hash:State_hash.t
  -> ( Transition_frontier.t
     * External_transition.Initial_validated.t Envelope.Incoming.t list )
     Deferred.t
