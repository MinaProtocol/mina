open Async_kernel
open Pipe_lib.Strict_pipe

module type Network_intf = sig
  type t

  type peer

  type state_hash

  type protocol_state

  type transition

  type ancestor_proof_input

  type ancestor_proof

  val random_peers : t -> int -> peer list

  val catchup_transition :
    t -> peer -> state_hash -> transition list option Deferred.Or_error.t

  val get_ancestry :
       t
    -> ancestor_proof_input
    -> (protocol_state * ancestor_proof) Deferred.Or_error.t
end

module type Transition_frontier_base_intf = sig
  type state_hash

  type external_transition

  type transaction_snark_scan_state

  type staged_ledger

  type ledger_diff

  module Breadcrumb : sig
    type t [@@deriving sexp]

    val create :
      (external_transition, state_hash) With_hash.t -> staged_ledger -> t

    val transition_with_hash :
      t -> (external_transition, state_hash) With_hash.t

    val staged_ledger : t -> staged_ledger
  end

  type ledger_database

  type t

  val create :
       logger:Logger.t
    -> root_transition:(external_transition, state_hash) With_hash.t
    -> root_snarked_ledger:ledger_database
    -> root_transaction_snark_scan_state:transaction_snark_scan_state
    -> root_staged_ledger_diff:ledger_diff option
    -> t

  val find_exn : t -> state_hash -> Breadcrumb.t
end

module type Transition_frontier_intf = sig
  include Transition_frontier_base_intf

  exception
    Parent_not_found of ([`Parent of state_hash] * [`Target of state_hash])

  exception Already_exists of state_hash

  val max_length : int

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

  val attach_breadcrumb_exn : t -> Breadcrumb.t -> unit

  val add_transition_exn :
    t -> (external_transition, state_hash) With_hash.t -> Breadcrumb.t

  val clear_paths : t -> unit

  (* TODO: Rather than rebuilding the same transition_frontier, it would be better to 
  change the reference of the frontier that every component that the transition_frontier 
  contains #1323 *)
  (* TODO: after caching external transitions, we should recreate transition_frontier #1326*)
  val rebuild : t -> state_hash -> unit
end

module type Catchup_intf = sig
  type state_hash

  type external_transition

  type transition_frontier

  type transition_frontier_breadcrumb

  type network

  val run :
       logger:Logger.t
    -> network:network
    -> frontier:transition_frontier
    -> catchup_job_reader:(external_transition, state_hash) With_hash.t
                          Reader.t
    -> catchup_breadcrumbs_writer:( transition_frontier_breadcrumb list
                                  , crash buffered
                                  , unit )
                                  Writer.t
    -> unit
end

module type Transition_handler_validator_intf = sig
  type time

  type state_hash

  type external_transition

  type transition_frontier

  val run :
       logger:Logger.t
    -> frontier:transition_frontier
    -> transition_reader:( [ `Transition of external_transition
                                            Envelope.Incoming.t ]
                         * [`Time_received of time] )
                         Reader.t
    -> valid_transition_writer:( (external_transition, state_hash) With_hash.t
                               , drop_head buffered
                               , unit )
                               Writer.t
    -> unit
end

module type Transition_handler_processor_intf = sig
  type state_hash

  type time_controller

  type external_transition

  type transition_frontier

  type transition_frontier_breadcrumb

  val run :
       logger:Logger.t
    -> time_controller:time_controller
    -> frontier:transition_frontier
    -> valid_transition_reader:(external_transition, state_hash) With_hash.t
                               Reader.t
    -> catchup_job_writer:( (external_transition, state_hash) With_hash.t
                          , drop_head buffered
                          , unit )
                          Writer.t
    -> catchup_breadcrumbs_reader:transition_frontier_breadcrumb list Reader.t
    -> processed_transition_writer:( ( external_transition
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

  type external_transition

  type transition_frontier

  type transition_frontier_breadcrumb

  module Validator :
    Transition_handler_validator_intf
    with type time := time
     and type state_hash := state_hash
     and type external_transition := external_transition
     and type transition_frontier := transition_frontier

  module Processor :
    Transition_handler_processor_intf
    with type time_controller := time_controller
     and type external_transition := external_transition
     and type state_hash := state_hash
     and type transition_frontier := transition_frontier
     and type transition_frontier_breadcrumb := transition_frontier_breadcrumb
end

module type Sync_handler_intf = sig
  type hash

  type transition_frontier

  type ancestor_proof

  val prove_ancestry :
       frontier:transition_frontier
    -> int
    -> hash
    -> (hash * ancestor_proof) option
end

module type Bootstrap_controller_intf = sig
  type network

  type transition_frontier

  type external_transition

  type ancestor_prover

  type ledger_db

  val run :
       parent_log:Logger.t
    -> network:network
    -> ancestor_prover:ancestor_prover
    -> frontier:transition_frontier
    -> ledger_db:ledger_db
    -> transition_reader:( [< `Transition of external_transition
                                             Envelope.Incoming.t ]
                         * [< `Time_received of int64] )
                         Reader.t
    -> unit Deferred.t
end

module type Transition_frontier_controller_intf = sig
  type time_controller

  type external_transition

  type state_hash

  type transition_frontier

  type network

  type time

  val run :
       logger:Logger.t
    -> network:network
    -> time_controller:time_controller
    -> frontier:transition_frontier
    -> transition_reader:( [ `Transition of external_transition
                                            Envelope.Incoming.t ]
                         * [`Time_received of time] )
                         Reader.t
    -> clear_reader:[`Clear] Reader.t
    -> (external_transition, state_hash) With_hash.t Reader.t
end

module type Transition_router_intf = sig
  type time_controller

  type external_transition

  type state_hash

  type transition_frontier

  type network

  type time

  type ledger_db

  val run :
       logger:Logger.t
    -> network:network
    -> time_controller:time_controller
    -> frontier:transition_frontier
    -> ledger_db:ledger_db
    -> transition_reader:( [ `Transition of external_transition
                                            Envelope.Incoming.t ]
                         * [`Time_received of time] )
                         Reader.t
    -> (external_transition, state_hash) With_hash.t Reader.t
end
