open Core
open Async_kernel
open Pipe_lib
open Cache_lib
open Coda_base
open Coda_transition

module type Catchup_intf = sig
  type unprocessed_transition_cache

  type transition_frontier

  type transition_frontier_breadcrumb

  type network

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> network:network
    -> frontier:transition_frontier
    -> catchup_job_reader:( State_hash.t
                          * ( External_transition.Initial_validated.t
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
                                    * [ `Ledger_catchup of unit Ivar.t
                                      | `Catchup_scheduler ]
                                  , Strict_pipe.crash Strict_pipe.buffered
                                  , unit )
                                  Strict_pipe.Writer.t
    -> unprocessed_transition_cache:unprocessed_transition_cache
    -> unit
end

module type Transition_handler_validator_intf = sig
  type unprocessed_transition_cache

  type transition_frontier

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> frontier:transition_frontier
    -> transition_reader:( [ `Transition of
                             External_transition.Initial_validated.t
                             Envelope.Incoming.t ]
                         * [`Time_received of Block_time.t] )
                         Strict_pipe.Reader.t
    -> valid_transition_writer:( ( External_transition.Initial_validated.t
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
    -> External_transition.Initial_validated.t Envelope.Incoming.t
    -> ( ( External_transition.Initial_validated.t Envelope.Incoming.t
         , State_hash.t )
         Cached.t
       , [> `In_frontier of State_hash.t
         | `In_process of State_hash.t Cache_lib.Intf.final_state
         | `Disconnected ] )
       Result.t
end

module type Breadcrumb_builder_intf = sig
  type transition_frontier

  type transition_frontier_breadcrumb

  val build_subtrees_of_breadcrumbs :
       logger:Logger.t
    -> verifier:Verifier.t
    -> trust_system:Trust_system.t
    -> frontier:transition_frontier
    -> initial_hash:State_hash.t
    -> ( External_transition.Initial_validated.t Envelope.Incoming.t
       , State_hash.t )
       Cached.t
       Rose_tree.t
       List.t
    -> (transition_frontier_breadcrumb, State_hash.t) Cached.t Rose_tree.t
       List.t
       Deferred.Or_error.t
end

module type Transition_handler_processor_intf = sig
  type transition_frontier

  type transition_frontier_breadcrumb

  val run :
       logger:Logger.t
    -> verifier:Verifier.t
    -> trust_system:Trust_system.t
    -> time_controller:Block_time.Controller.t
    -> frontier:transition_frontier
    -> primary_transition_reader:( External_transition.Initial_validated.t
                                   Envelope.Incoming.t
                                 , State_hash.t )
                                 Cached.t
                                 Strict_pipe.Reader.t
    -> proposer_transition_reader:transition_frontier_breadcrumb
                                  Strict_pipe.Reader.t
    -> clean_up_catchup_scheduler:unit Ivar.t
    -> catchup_job_writer:( State_hash.t
                            * ( External_transition.Initial_validated.t
                                Envelope.Incoming.t
                              , State_hash.t )
                              Cached.t
                              Rose_tree.t
                              list
                          , Strict_pipe.crash Strict_pipe.buffered
                          , unit )
                          Strict_pipe.Writer.t
    -> catchup_breadcrumbs_reader:( ( transition_frontier_breadcrumb
                                    , State_hash.t )
                                    Cached.t
                                    Rose_tree.t
                                    list
                                  * [ `Ledger_catchup of unit Ivar.t
                                    | `Catchup_scheduler ] )
                                  Strict_pipe.Reader.t
    -> catchup_breadcrumbs_writer:( ( transition_frontier_breadcrumb
                                    , State_hash.t )
                                    Cached.t
                                    Rose_tree.t
                                    list
                                    * [ `Ledger_catchup of unit Ivar.t
                                      | `Catchup_scheduler ]
                                  , Strict_pipe.crash Strict_pipe.buffered
                                  , unit )
                                  Strict_pipe.Writer.t
    -> processed_transition_writer:( External_transition.Validated.t
                                   , Strict_pipe.crash Strict_pipe.buffered
                                   , unit )
                                   Strict_pipe.Writer.t
    -> unit
end

module type Unprocessed_transition_cache_intf = sig
  type t

  val create : logger:Logger.t -> t

  val register_exn :
       t
    -> External_transition.Initial_validated.t Envelope.Incoming.t
    -> ( External_transition.Initial_validated.t Envelope.Incoming.t
       , State_hash.t )
       Cached.t
end

module type Transition_handler_intf = sig
  type transition_frontier

  type transition_frontier_breadcrumb

  module Unprocessed_transition_cache : Unprocessed_transition_cache_intf

  module Breadcrumb_builder :
    Breadcrumb_builder_intf
    with type transition_frontier := transition_frontier
     and type transition_frontier_breadcrumb := transition_frontier_breadcrumb

  module Validator :
    Transition_handler_validator_intf
    with type unprocessed_transition_cache := Unprocessed_transition_cache.t
     and type transition_frontier := transition_frontier

  module Processor :
    Transition_handler_processor_intf
    with type transition_frontier := transition_frontier
     and type transition_frontier_breadcrumb := transition_frontier_breadcrumb
end

(** Interface that allows a peer to prove their best_tip in the
    transition_frontier *)
module type Best_tip_prover_intf = sig
  type transition_frontier

  val prove :
       logger:Logger.t
    -> transition_frontier
    -> ( External_transition.t
       , State_body_hash.t list * External_transition.t )
       Proof_carrying_data.t
       option

  val verify :
       verifier:Verifier.t
    -> ( External_transition.t
       , State_body_hash.t list * External_transition.t )
       Proof_carrying_data.t
    -> ( [`Root of External_transition.Initial_validated.t]
       * [`Best_tip of External_transition.Initial_validated.t] )
       Deferred.Or_error.t
end

(** Interface that allows a peer to prove their best_tip in the
    transition_frontier based off of a condition on the consensus_state from
    the requesting node *)
module type Consensus_best_tip_prover_intf = sig
  type transition_frontier

  val prove :
       logger:Logger.t
    -> frontier:transition_frontier
    -> Consensus.Data.Consensus_state.Value.t
    -> ( External_transition.t
       , State_body_hash.t list * External_transition.t )
       Proof_carrying_data.t
       option

  val verify :
       logger:Logger.t
    -> verifier:Verifier.t
    -> Consensus.Data.Consensus_state.Value.t
    -> ( External_transition.t
       , State_body_hash.t list * External_transition.t )
       Proof_carrying_data.t
    -> ( [`Root of External_transition.Initial_validated.t]
       * [`Best_tip of External_transition.Initial_validated.t] )
       Deferred.Or_error.t
end

module type Sync_handler_intf = sig
  type transition_frontier

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
    -> (Staged_ledger.Scan_state.t * Ledger_hash.t * Pending_coinbase.t)
       Option.t

  val get_transition_chain :
       frontier:transition_frontier
    -> State_hash.t sexp_list
    -> External_transition.t sexp_list option

  (** Allows a peer to prove to a node that they can bootstrap from transition
      that they have gossiped to the network *)
  module Root :
    Consensus_best_tip_prover_intf
    with type transition_frontier := transition_frontier

  (** Allows a node to ask peers for their best tip in order to help them
      bootstrap *)
  module Bootstrappable_best_tip : sig
    include
      Consensus_best_tip_prover_intf
      with type transition_frontier := transition_frontier

    module For_tests : sig
      val prove :
           logger:Logger.t
        -> should_select_tip:(   existing:Consensus.Data.Consensus_state.Value.t
                              -> candidate:Consensus.Data.Consensus_state.Value
                                           .t
                              -> logger:Logger.t
                              -> bool)
        -> frontier:transition_frontier
        -> Consensus.Data.Consensus_state.Value.t
        -> ( External_transition.t
           , State_body_hash.t list * External_transition.t )
           Proof_carrying_data.t
           option

      val verify :
           logger:Logger.t
        -> should_select_tip:(   existing:Consensus.Data.Consensus_state.Value.t
                              -> candidate:Consensus.Data.Consensus_state.Value
                                           .t
                              -> logger:Logger.t
                              -> bool)
        -> verifier:Verifier.t
        -> Consensus.Data.Consensus_state.Value.t
        -> ( External_transition.t
           , State_body_hash.t list * External_transition.t )
           Proof_carrying_data.t
        -> ( [`Root of External_transition.Initial_validated.t]
           * [`Best_tip of External_transition.Initial_validated.t] )
           Deferred.Or_error.t
    end
  end
end

module type Transition_chain_prover_intf = sig
  type transition_frontier

  val prove :
       ?length:int
    -> frontier:transition_frontier
    -> State_hash.t
    -> (State_hash.t * State_body_hash.t list) option
end

module type Bootstrap_controller_intf = sig
  type network

  type transition_frontier

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> network:network
    -> frontier:transition_frontier
    -> ledger_db:Ledger.Db.t
    -> transition_reader:( [< `Transition of
                              External_transition.Initial_validated.t
                              Envelope.Incoming.t ]
                         * [< `Time_received of Block_time.t] )
                         Strict_pipe.Reader.t
    -> ( transition_frontier
       * External_transition.Initial_validated.t Envelope.Incoming.t list )
       Deferred.t
end

module type Transition_frontier_controller_intf = sig
  type transition_frontier

  type breadcrumb

  type network

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> network:network
    -> time_controller:Block_time.Controller.t
    -> collected_transitions:External_transition.Initial_validated.t
                             Envelope.Incoming.t
                             list
    -> frontier:transition_frontier
    -> network_transition_reader:( [ `Transition of
                                     External_transition.Initial_validated.t
                                     Envelope.Incoming.t ]
                                 * [`Time_received of Block_time.t] )
                                 Strict_pipe.Reader.t
    -> proposer_transition_reader:breadcrumb Strict_pipe.Reader.t
    -> clear_reader:[`Clear] Strict_pipe.Reader.t
    -> External_transition.Validated.t Strict_pipe.Reader.t
end
