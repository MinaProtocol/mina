open Core
open Async_kernel
open Pipe_lib
open Cache_lib
open Coda_base

module type Catchup_intf = sig
  type external_transition_with_initial_validation

  type unprocessed_transition_cache

  type transition_frontier

  type transition_frontier_breadcrumb

  type network

  type verifier

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:verifier
    -> network:network
    -> frontier:transition_frontier
    -> catchup_job_reader:( State_hash.t
                          * ( external_transition_with_initial_validation
                              Envelope.Incoming.t
                            , State_hash.t )
                            Cached.t
                            Rose_tree.t
                            list )
                          Strict_pipe.Reader.t
    -> catchup_breadcrumbs_writer:( ( transition_frontier_breadcrumb
                                    , State_hash.t )
                                    Cached.t
                                    Rose_tree.t
                                    list
                                  , Strict_pipe.crash Strict_pipe.buffered
                                  , unit )
                                  Strict_pipe.Writer.t
    -> unprocessed_transition_cache:unprocessed_transition_cache
    -> unit
end

module type Transition_handler_validator_intf = sig
  type external_transition_with_initial_validation

  type unprocessed_transition_cache

  type transition_frontier

  type staged_ledger

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> frontier:transition_frontier
    -> transition_reader:( [ `Transition of
                             external_transition_with_initial_validation
                             Envelope.Incoming.t ]
                         * [`Time_received of Block_time.t] )
                         Strict_pipe.Reader.t
    -> valid_transition_writer:( ( external_transition_with_initial_validation
                                   Envelope.Incoming.t
                                 , State_hash.t )
                                 Cached.t
                               , Strict_pipe.crash Strict_pipe.buffered
                               , unit )
                               Strict_pipe.Writer.t
    -> unprocessed_transition_cache:unprocessed_transition_cache
    -> unit

  val validate_transition :
       logger:Logger.t
    -> frontier:transition_frontier
    -> unprocessed_transition_cache:unprocessed_transition_cache
    -> external_transition_with_initial_validation Envelope.Incoming.t
    -> ( ( external_transition_with_initial_validation Envelope.Incoming.t
         , State_hash.t )
         Cached.t
       , [ `In_frontier of State_hash.t
         | `In_process of State_hash.t Cache_lib.Intf.final_state
         | `Disconnected ] )
       Result.t
end

module type Breadcrumb_builder_intf = sig
  type transition_frontier

  type transition_frontier_breadcrumb

  type external_transition_with_initial_validation

  type verifier

  val build_subtrees_of_breadcrumbs :
       logger:Logger.t
    -> verifier:verifier
    -> trust_system:Trust_system.t
    -> frontier:transition_frontier
    -> initial_hash:State_hash.t
    -> ( external_transition_with_initial_validation Envelope.Incoming.t
       , State_hash.t )
       Cached.t
       Rose_tree.t
       List.t
    -> (transition_frontier_breadcrumb, State_hash.t) Cached.t Rose_tree.t
       List.t
       Deferred.Or_error.t
end

module type Transition_handler_processor_intf = sig
  type external_transition_validated

  type external_transition_with_initial_validation

  type transition_frontier

  type transition_frontier_breadcrumb

  type verifier

  val run :
       logger:Logger.t
    -> verifier:verifier
    -> trust_system:Trust_system.t
    -> time_controller:Block_time.Controller.t
    -> frontier:transition_frontier
    -> primary_transition_reader:( external_transition_with_initial_validation
                                   Envelope.Incoming.t
                                 , State_hash.t )
                                 Cached.t
                                 Strict_pipe.Reader.t
    -> proposer_transition_reader:transition_frontier_breadcrumb
                                  Strict_pipe.Reader.t
    -> clean_up_catchup_scheduler:unit Ivar.t
    -> catchup_job_writer:( State_hash.t
                            * ( external_transition_with_initial_validation
                                Envelope.Incoming.t
                              , State_hash.t )
                              Cached.t
                              Rose_tree.t
                              list
                          , Strict_pipe.crash Strict_pipe.buffered
                          , unit )
                          Strict_pipe.Writer.t
    -> catchup_breadcrumbs_reader:( transition_frontier_breadcrumb
                                  , State_hash.t )
                                  Cached.t
                                  Rose_tree.t
                                  list
                                  Strict_pipe.Reader.t
    -> catchup_breadcrumbs_writer:( ( transition_frontier_breadcrumb
                                    , State_hash.t )
                                    Cached.t
                                    Rose_tree.t
                                    list
                                  , Strict_pipe.crash Strict_pipe.buffered
                                  , unit )
                                  Strict_pipe.Writer.t
    -> processed_transition_writer:( ( external_transition_validated
                                     , State_hash.t )
                                     With_hash.t
                                   , Strict_pipe.crash Strict_pipe.buffered
                                   , unit )
                                   Strict_pipe.Writer.t
    -> unit
end

module type Unprocessed_transition_cache_intf = sig
  type external_transition_with_initial_validation

  type t

  val create : logger:Logger.t -> t

  val register_exn :
       t
    -> external_transition_with_initial_validation Envelope.Incoming.t
    -> ( external_transition_with_initial_validation Envelope.Incoming.t
       , State_hash.t )
       Cached.t
end

module type Transition_handler_intf = sig
  type verifier

  type external_transition_with_initial_validation

  type external_transition_validated

  type transition_frontier

  type staged_ledger

  type transition_frontier_breadcrumb

  module Unprocessed_transition_cache :
    Unprocessed_transition_cache_intf
    with type external_transition_with_initial_validation :=
                external_transition_with_initial_validation

  module Breadcrumb_builder :
    Breadcrumb_builder_intf
    with type verifier := verifier
     and type external_transition_with_initial_validation :=
                external_transition_with_initial_validation
     and type transition_frontier := transition_frontier
     and type transition_frontier_breadcrumb := transition_frontier_breadcrumb

  module Validator :
    Transition_handler_validator_intf
    with type external_transition_with_initial_validation :=
                external_transition_with_initial_validation
     and type unprocessed_transition_cache := Unprocessed_transition_cache.t
     and type transition_frontier := transition_frontier
     and type staged_ledger := staged_ledger

  module Processor :
    Transition_handler_processor_intf
    with type external_transition_validated := external_transition_validated
     and type external_transition_with_initial_validation :=
                external_transition_with_initial_validation
     and type verifier := verifier
     and type transition_frontier := transition_frontier
     and type transition_frontier_breadcrumb := transition_frontier_breadcrumb
end

module type Sync_handler_intf = sig
  type transition_frontier

  type external_transition

  type external_transition_validated

  type parallel_scan_state

  val answer_query :
       frontier:transition_frontier
    -> Ledger_hash.t
    -> Sync_ledger.Query.t Envelope.Incoming.t
    -> logger:Logger.t
    -> trust_system:Trust_system.t
    -> Sync_ledger.Answer.t option Deferred.t

  val get_staged_ledger_aux_and_pending_coinbases_at_hash :
       frontier:transition_frontier
    -> State_hash.t
    -> (parallel_scan_state * Ledger_hash.t * Pending_coinbase.t) Option.t
end

module type Transition_chain_witness_intf = sig
  type transition_frontier

  type external_transition

  val prove :
       frontier:transition_frontier
    -> State_hash.t
    -> (State_hash.t * State_body_hash.t List.t) Option.t

  val verify :
       target_hash:State_hash.t
    -> transition_chain_witness:State_hash.t * State_body_hash.t List.t
    -> State_hash.t Non_empty_list.t option
end

module type Root_prover_intf = sig
  type transition_frontier

  type external_transition

  type external_transition_with_initial_validation

  type verifier

  val prove :
       logger:Logger.t
    -> frontier:transition_frontier
    -> Consensus.Data.Consensus_state.Value.t
    -> ( external_transition
       , State_body_hash.t list * external_transition )
       Proof_carrying_data.t
       option

  val verify :
       logger:Logger.t
    -> verifier:verifier
    -> observed_state:Consensus.Data.Consensus_state.Value.t
    -> peer_root:( external_transition
                 , State_body_hash.t list * external_transition )
                 Proof_carrying_data.t
    -> ( external_transition_with_initial_validation
       * external_transition_with_initial_validation )
       Deferred.Or_error.t
end

module type Bootstrap_controller_intf = sig
  type network

  type verifier

  type transition_frontier

  type external_transition_with_initial_validation

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:verifier
    -> network:network
    -> frontier:transition_frontier
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> transition_reader:( [< `Transition of
                              external_transition_with_initial_validation
                              Envelope.Incoming.t ]
                         * [< `Time_received of Block_time.t] )
                         Strict_pipe.Reader.t
    -> ( transition_frontier
       * external_transition_with_initial_validation Envelope.Incoming.t list
       )
       Deferred.t
end

module type Transition_frontier_controller_intf = sig
  type external_transition_validated

  type external_transition_with_initial_validation

  type transition_frontier

  type breadcrumb

  type network

  type verifier

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:verifier
    -> network:network
    -> time_controller:Block_time.Controller.t
    -> collected_transitions:external_transition_with_initial_validation
                             Envelope.Incoming.t
                             list
    -> frontier:transition_frontier
    -> network_transition_reader:( [ `Transition of
                                     external_transition_with_initial_validation
                                     Envelope.Incoming.t ]
                                 * [`Time_received of Block_time.t] )
                                 Strict_pipe.Reader.t
    -> proposer_transition_reader:breadcrumb Strict_pipe.Reader.t
    -> clear_reader:[`Clear] Strict_pipe.Reader.t
    -> (external_transition_validated, State_hash.t) With_hash.t
       Strict_pipe.Reader.t
end

module type Initial_validator_intf = sig
  type external_transition

  type external_transition_with_initial_validation

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> transition_reader:( [ `Transition of
                             external_transition Envelope.Incoming.t ]
                         * [`Time_received of Block_time.t] )
                         Strict_pipe.Reader.t
    -> valid_transition_writer:( [ `Transition of
                                   external_transition_with_initial_validation
                                   Envelope.Incoming.t ]
                                 * [`Time_received of Block_time.t]
                               , Strict_pipe.crash Strict_pipe.buffered
                               , unit )
                               Strict_pipe.Writer.t
    -> unit
end

module type Transition_router_intf = sig
  type verifier

  type external_transition

  type external_transition_validated

  type transition_frontier

  type transition_frontier_persistent_root

  type breadcrumb

  type network

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:verifier
    -> network:network
    -> time_controller:Block_time.Controller.t
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> frontier_broadcast_pipe:transition_frontier option
                               Pipe_lib.Broadcast_pipe.Reader.t
                               * transition_frontier option
                                 Pipe_lib.Broadcast_pipe.Writer.t
    -> network_transition_reader:( [ `Transition of
                                     external_transition Envelope.Incoming.t ]
                                 * [`Time_received of Block_time.t] )
                                 Strict_pipe.Reader.t
    -> proposer_transition_reader:breadcrumb Strict_pipe.Reader.t
    -> (external_transition_validated, State_hash.t) With_hash.t
       Strict_pipe.Reader.t
end
