open Async_kernel
open Pipe_lib
open Cache_lib
open Mina_base
open Network_peer
module Best_tip_lru = Best_tip_lru

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val verifier : Verifier.t
end

module Catchup_jobs : sig
  val reader : int Broadcast_pipe.Reader.t
end

val run :
     context:(module CONTEXT)
  -> trust_system:Trust_system.t
  -> network:Mina_networking.t
  -> frontier:Transition_frontier.t
  -> catchup_job_reader:
       ( State_hash.t
       * ( ( Mina_block.initial_valid_block Envelope.Incoming.t
           , State_hash.t )
           Cached.t
         * Mina_net2.Validation_callback.t option )
         Rose_tree.t
         list )
       Strict_pipe.Reader.t
  -> catchup_breadcrumbs_writer:
       ( ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
         * Mina_net2.Validation_callback.t option )
         Rose_tree.t
         list
         * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ]
       , Strict_pipe.crash Strict_pipe.buffered
       , unit )
       Strict_pipe.Writer.t
  -> unprocessed_transition_cache:
       Transition_handler.Unprocessed_transition_cache.t
  -> unit
