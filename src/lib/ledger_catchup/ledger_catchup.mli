open Async_kernel
open Pipe_lib
open Cache_lib
open Coda_base
open Coda_transition
open Network_peer

module Catchup_jobs : sig
  val reader : int Broadcast_pipe.Reader.t
end

val run :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> network:Coda_networking.t
  -> frontier:Transition_frontier.t
  -> catchup_job_reader:( State_hash.t
                        * ( External_transition.Initial_validated.t
                            Envelope.Incoming.t
                          , State_hash.t )
                          Cached.t
                          Rose_tree.t
                          list )
                        Strict_pipe.Reader.t
  -> catchup_breadcrumbs_writer:( ( Transition_frontier.Breadcrumb.t
                                  , State_hash.t )
                                  Cached.t
                                  Rose_tree.t
                                  list
                                  * [ `Ledger_catchup of unit Ivar.t
                                    | `Catchup_scheduler ]
                                , Strict_pipe.crash Strict_pipe.buffered
                                , unit )
                                Strict_pipe.Writer.t
  -> unprocessed_transition_cache:Transition_handler
                                  .Unprocessed_transition_cache
                                  .t
  -> unit
