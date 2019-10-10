open Async_kernel
open Core
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
  -> ( Transition_frontier.t
     * External_transition.Initial_validated.t Envelope.Incoming.t list )
     Deferred.t

module For_tests : sig
  type t

  val make_bootstrap :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> genesis_root:External_transition.Validated.t
    -> network:Coda_networking.t
    -> t

  val on_transition :
       t
    -> sender:Unix.Inet_addr.t
    -> root_sync_ledger:(State_hash.t * Unix.Inet_addr.t * Staged_ledger_hash.t)
                        Sync_ledger.Db.t
    -> External_transition.t
    -> [> `Syncing_new_snarked_ledger | `Updating_root_transition | `Ignored]
       Deferred.t

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
                         Pipe_lib.Strict_pipe.Reader.t
    -> should_ask_best_tip:bool
    -> persistent_root:Transition_frontier.Persistent_root.t
    -> persistent_frontier:Transition_frontier.Persistent_frontier.t
    -> initial_root_transition:External_transition.Validated.t
    -> ( Transition_frontier.t
       * External_transition.Initial_validated.t Envelope.Incoming.t list )
       Deferred.t

  val sync_ledger :
       t
    -> root_sync_ledger:(State_hash.t * Unix.Inet_addr.t * Staged_ledger_hash.t)
                        Sync_ledger.Db.t
    -> transition_graph:Transition_cache.t
    -> sync_ledger_reader:( [< `Transition of
                               External_transition.Initial_validated.t
                               Envelope.Incoming.t ]
                          * [< `Time_received of 'a] )
                          Pipe_lib.Strict_pipe.Reader.t
    -> unit Deferred.t
end
