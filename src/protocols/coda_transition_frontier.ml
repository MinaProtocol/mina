open Core_kernel
open Async_kernel
open Pipe_lib.Strict_pipe

module type Network_intf = sig
  type t

  type peer

  type state_hash

  type ledger_hash

  type consensus_state

  type sync_ledger_query

  type sync_ledger_answer

  type external_transition

  type state_body_hash

  val random_peers : t -> int -> peer list

  val catchup_transition :
       t
    -> peer
    -> state_hash
    -> external_transition list option Deferred.Or_error.t

  val get_ancestry :
       t
    -> peer
    -> consensus_state
    -> ( external_transition
       , state_body_hash list * external_transition )
       Proof_carrying_data.t
       Deferred.Or_error.t

  (* TODO: Change this to strict_pipe *)
  val glue_sync_ledger :
       t
    -> (ledger_hash * sync_ledger_query) Pipe_lib.Linear_pipe.Reader.t
    -> (ledger_hash * sync_ledger_answer) Envelope.Incoming.t
       Pipe_lib.Linear_pipe.Writer.t
    -> unit
end

module type Transition_frontier_base_intf = sig
  type state_hash

  type external_transition_verified

  type transaction_snark_scan_state

  type masked_ledger

  type staged_ledger

  type consensus_local_state

  module Breadcrumb : sig
    type t [@@deriving sexp]

    val create :
         (external_transition_verified, state_hash) With_hash.t
      -> staged_ledger
      -> t

    val build :
         logger:Logger.t
      -> parent:t
      -> transition_with_hash:( external_transition_verified
                              , state_hash )
                              With_hash.t
      -> (t, [`Validation_error of Error.t | `Fatal_error of exn]) Result.t
         Deferred.t

    val transition_with_hash :
      t -> (external_transition_verified, state_hash) With_hash.t

    val staged_ledger : t -> staged_ledger
  end

  type ledger_database

  type staged_ledger_diff

  type t

  val create :
       logger:Logger.t
    -> root_transition:(external_transition_verified, state_hash) With_hash.t
    -> root_snarked_ledger:ledger_database
    -> root_transaction_snark_scan_state:transaction_snark_scan_state
    -> root_staged_ledger_diff:staged_ledger_diff option
    -> consensus_local_state:consensus_local_state
    -> t Deferred.t

  val find_exn : t -> state_hash -> Breadcrumb.t

  val logger : t -> Logger.t
end

module type Transition_frontier_intf = sig
  include Transition_frontier_base_intf

  exception
    Parent_not_found of ([`Parent of state_hash] * [`Target of state_hash])

  exception Already_exists of state_hash

  val max_length : int

  val consensus_local_state : t -> consensus_local_state

  val all_breadcrumbs : t -> Breadcrumb.t list

  val root : t -> Breadcrumb.t

  val best_tip : t -> Breadcrumb.t

  val path_map : t -> Breadcrumb.t -> f:(Breadcrumb.t -> 'a) -> 'a list

  val hash_path : t -> Breadcrumb.t -> state_hash list

  val find : t -> state_hash -> Breadcrumb.t option

  val successor_hashes : t -> state_hash -> state_hash list

  val successor_hashes_rec : t -> state_hash -> state_hash list

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list

  val successors_rec : t -> Breadcrumb.t -> Breadcrumb.t list

  val iter : t -> f:(Breadcrumb.t -> unit) -> unit

  val add_breadcrumb_exn : t -> Breadcrumb.t -> unit

  val clear_paths : t -> unit

  val best_tip_path_length_exn : t -> int

  module For_tests : sig
    val root_snarked_ledger : t -> ledger_database
  end
end

module type Catchup_intf = sig
  type state_hash

  type external_transition_verified

  type transition_frontier

  type transition_frontier_breadcrumb

  type network

  val run :
       logger:Logger.t
    -> network:network
    -> frontier:transition_frontier
    -> catchup_job_reader:( external_transition_verified
                          , state_hash )
                          With_hash.t
                          Reader.t
    -> catchup_breadcrumbs_writer:( transition_frontier_breadcrumb Rose_tree.t
                                    list
                                  , synchronous
                                  , unit Deferred.t )
                                  Writer.t
    -> unit
end

module type Transition_handler_validator_intf = sig
  type time

  type state_hash

  type external_transition_verified

  type transition_frontier

  type staged_ledger

  val run :
       logger:Logger.t
    -> frontier:transition_frontier
    -> transition_reader:( [ `Transition of external_transition_verified
                                            Envelope.Incoming.t ]
                         * [`Time_received of time] )
                         Reader.t
    -> valid_transition_writer:( ( external_transition_verified
                                 , state_hash )
                                 With_hash.t
                               , drop_head buffered
                               , unit )
                               Writer.t
    -> unit

  val validate_transition :
       logger:Logger.t
    -> frontier:transition_frontier
    -> (external_transition_verified, state_hash) With_hash.t
    -> (unit, [`Duplicate | `Invalid of string]) Result.t
end

module type Transition_handler_processor_intf = sig
  type state_hash

  type time_controller

  type external_transition_verified

  type transition_frontier

  type transition_frontier_breadcrumb

  val run :
       logger:Logger.t
    -> time_controller:time_controller
    -> frontier:transition_frontier
    -> primary_transition_reader:( external_transition_verified
                                 , state_hash )
                                 With_hash.t
                                 Reader.t
    -> proposer_transition_reader:( external_transition_verified
                                  , state_hash )
                                  With_hash.t
                                  Reader.t
    -> catchup_job_writer:( ( external_transition_verified
                            , state_hash )
                            With_hash.t
                          , synchronous
                          , unit Deferred.t )
                          Writer.t
    -> catchup_breadcrumbs_reader:transition_frontier_breadcrumb Rose_tree.t
                                  list
                                  Reader.t
    -> catchup_breadcrumbs_writer:( transition_frontier_breadcrumb Rose_tree.t
                                    list
                                  , synchronous
                                  , unit Deferred.t )
                                  Writer.t
    -> processed_transition_writer:( ( external_transition_verified
                                     , state_hash )
                                     With_hash.t
                                   , drop_head buffered
                                   , unit )
                                   Writer.t
    -> unit
end

module type Transition_handler_intf = sig
  type time_controller

  type time

  type state_hash

  type external_transition_verified

  type transition_frontier

  type staged_ledger

  type transition_frontier_breadcrumb

  module Validator :
    Transition_handler_validator_intf
    with type time := time
     and type state_hash := state_hash
     and type external_transition_verified := external_transition_verified
     and type transition_frontier := transition_frontier
     and type staged_ledger := staged_ledger

  module Processor :
    Transition_handler_processor_intf
    with type time_controller := time_controller
     and type external_transition_verified := external_transition_verified
     and type state_hash := state_hash
     and type transition_frontier := transition_frontier
     and type transition_frontier_breadcrumb := transition_frontier_breadcrumb
end

module type Sync_handler_intf = sig
  type ledger_hash

  type transition_frontier

  type syncable_ledger_query

  type syncable_ledger_answer

  val answer_query :
       frontier:transition_frontier
    -> ledger_hash
    -> syncable_ledger_query
    -> logger:Logger.t
    -> (ledger_hash * syncable_ledger_answer) option
end

module type Root_prover_intf = sig
  type state_body_hash

  type state_hash

  type transition_frontier

  type external_transition

  type consensus_state

  type proof_verified_external_transition

  val prove :
       logger:Logger.t
    -> frontier:transition_frontier
    -> consensus_state
    -> ( external_transition
       , state_body_hash list * external_transition )
       Proof_carrying_data.t
       option

  val verify :
       logger:Logger.t
    -> observed_state:consensus_state
    -> peer_root:( external_transition
                 , state_body_hash list * external_transition )
                 Proof_carrying_data.t
    -> ( (proof_verified_external_transition, state_hash) With_hash.t
       * (proof_verified_external_transition, state_hash) With_hash.t )
       Deferred.Or_error.t
end

module type Bootstrap_controller_intf = sig
  type network

  type transition_frontier

  type external_transition_verified

  type ledger_db

  val run :
       parent_log:Logger.t
    -> network:network
    -> frontier:transition_frontier
    -> ledger_db:ledger_db
    -> transition_reader:( [< `Transition of external_transition_verified
                                             Envelope.Incoming.t ]
                         * [< `Time_received of int64] )
                         Reader.t
    -> (transition_frontier * external_transition_verified list) Deferred.t
end

module type Transition_frontier_controller_intf = sig
  type time_controller

  type external_transition_verified

  type state_hash

  type transition_frontier

  type network

  type time

  val run :
       logger:Logger.t
    -> network:network
    -> time_controller:time_controller
    -> collected_transitions:( external_transition_verified
                             , state_hash )
                             With_hash.t
                             list
    -> frontier:transition_frontier
    -> network_transition_reader:( [ `Transition of external_transition_verified
                                                    Envelope.Incoming.t ]
                                 * [`Time_received of time] )
                                 Reader.t
    -> proposer_transition_reader:( external_transition_verified
                                  , state_hash )
                                  With_hash.t
                                  Reader.t
    -> clear_reader:[`Clear] Reader.t
    -> (external_transition_verified, state_hash) With_hash.t Reader.t
end

module type Protocol_state_validator_intf = sig
  type time

  type state_hash

  type external_transition

  type external_transition_proof_verified

  type external_transition_verified

  val validate_proof :
       external_transition
    -> external_transition_proof_verified Or_error.t Deferred.t

  val validate_consensus_state :
       time_received:time
    -> external_transition
    -> external_transition_verified Or_error.t Deferred.t
end

module type Initial_validator_intf = sig
  type time

  type state_hash

  type external_transition

  type external_transition_verified

  val run :
       logger:Logger.t
    -> transition_reader:( [ `Transition of external_transition
                                            Envelope.Incoming.t ]
                         * [`Time_received of time] )
                         Reader.t
    -> valid_transition_writer:( [ `Transition of external_transition_verified
                                                  Envelope.Incoming.t ]
                                 * [`Time_received of time]
                               , drop_head buffered
                               , unit )
                               Writer.t
    -> unit
end

module type Transition_router_intf = sig
  type time_controller

  type external_transition

  type external_transition_verified

  type state_hash

  type transition_frontier

  type network

  type time

  type ledger_db

  val run :
       logger:Logger.t
    -> network:network
    -> time_controller:time_controller
    -> frontier_mvar:transition_frontier Mvar.Read_write.t
    -> ledger_db:ledger_db
    -> network_transition_reader:( [ `Transition of external_transition
                                                    Envelope.Incoming.t ]
                                 * [`Time_received of time] )
                                 Reader.t
    -> proposer_transition_reader:( external_transition_verified
                                  , state_hash )
                                  With_hash.t
                                  Reader.t
    -> (external_transition_verified, state_hash) With_hash.t Reader.t
end
