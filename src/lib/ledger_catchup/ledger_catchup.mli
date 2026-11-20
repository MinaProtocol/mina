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

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

module Catchup_jobs : sig
  val reader : int Broadcast_pipe.Reader.t
end

(** Set up catchup for [frontier], and return the function that handles one
    catchup job: the parent hash of a forest of blocks whose ancestry is
    missing, and the forest. Catchup resumes its waiting work by passing it to
    [schedule], which must run what it is given one at a time, in order. *)
val create_job_handler :
     context:(module CONTEXT)
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> network:Mina_networking.t
  -> frontier:Transition_frontier.t
  -> catchup_breadcrumbs_writer:
       ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
         Mina_stdlib.Rose_tree.t
         list
         * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ]
       , Strict_pipe.crash Strict_pipe.buffered
       , unit )
       Strict_pipe.Writer.t
  -> block_registry:Transition_handler.Block_registry.t
  -> in_flight:Otp_lib.In_flight.t
  -> schedule:((unit -> unit) -> unit)
  -> (   State_hash.t
         * ( Mina_block.initial_valid_block Envelope.Incoming.t
           , State_hash.t )
           Cached.t
           Mina_stdlib.Rose_tree.t
           list
      -> unit )
     Deferred.t
