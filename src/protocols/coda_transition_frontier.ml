open Pipe_lib.Strict_pipe

module type Transition_frontier_base_intf = sig
  type state_hash

  type external_transition

  type transaction_snark_scan_state

  type ledger_database

  type ledger_diff

  type t

  val create :
       logger:Logger.t
    -> root_transition:(external_transition, state_hash) With_hash.t
    -> root_snarked_ledger:ledger_database
    -> root_transaction_snark_scan_state:transaction_snark_scan_state
    -> root_staged_ledger_diff:ledger_diff option
    -> t
end

module type Transition_frontier_intf = sig
  include Transition_frontier_base_intf

  type staged_ledger

  exception
    Parent_not_found of ([`Parent of state_hash] * [`Target of state_hash])

  exception Already_exists of state_hash

  val max_length : int

  module Breadcrumb : sig
    type t [@@deriving sexp]

    val transition_with_hash :
      t -> (external_transition, state_hash) With_hash.t

    val staged_ledger : t -> staged_ledger
  end

  val root : t -> Breadcrumb.t

  val best_tip : t -> Breadcrumb.t

  val path : t -> Breadcrumb.t -> state_hash list

  val find : t -> state_hash -> Breadcrumb.t option

  val find_exn : t -> state_hash -> Breadcrumb.t

  val successor_hashes : t -> state_hash -> state_hash list

  val successor_hashes_rec : t -> state_hash -> state_hash list

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list

  val successors_rec : t -> Breadcrumb.t -> Breadcrumb.t list

  val iter : t -> f:(Breadcrumb.t -> unit) -> unit

  val attach_breadcrumb_exn : t -> Breadcrumb.t -> unit

  val add_transition_exn :
    t -> (external_transition, state_hash) With_hash.t -> Breadcrumb.t
end

module type Catchup_intf = sig
  type state_hash

  type external_transition

  type transition_frontier

  type transition_frontier_breadcrumb

  val run :
       frontier:transition_frontier
    -> catchup_job_reader:(external_transition, state_hash) With_hash.t
                          Reader.t
    -> catchup_breadcrumbs_writer:( transition_frontier_breadcrumb list
                                  , crash buffered
                                  , _ )
                                  Writer.t
    -> unit
end

module type Transition_handler_validator_intf = sig
  type state_hash

  type external_transition

  type transition_frontier

  val run :
       frontier:transition_frontier
    -> transition_reader:external_transition Reader.t
    -> valid_transition_writer:( (external_transition, state_hash) With_hash.t
                               , drop_head buffered
                               , _ )
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
    -> unit
end

module type Transition_handler_intf = sig
  type time_controller

  type state_hash

  type external_transition

  type transition_frontier

  type transition_frontier_breadcrumb

  module Validator :
    Transition_handler_validator_intf
    with type state_hash := state_hash
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
  type addr

  type hash

  type syncable_ledger

  type syncable_ledger_query

  type syncable_ledger_answer

  type transition_frontier

  val run :
       frontier:transition_frontier
    -> sync_query_reader:(hash * syncable_ledger_query) Reader.t
    -> sync_answer_writer:( hash * syncable_ledger_answer
                          , synchronous
                          , unit Async.Deferred.t )
                          Writer.t
    -> unit
end

module type Transition_frontier_controller_intf = sig
  type time_controller

  type external_transition

  type syncable_ledger_query

  type syncable_ledger_answer

  type transition_frontier

  type state_hash

  val run :
       logger:Logger.t
    -> time_controller:time_controller
    -> genesis_transition:external_transition
    -> transition_reader:external_transition Reader.t
    -> sync_query_reader:(state_hash * syncable_ledger_query) Reader.t
    -> sync_answer_writer:( state_hash * syncable_ledger_answer
                          , synchronous
                          , unit Async.Deferred.t )
                          Writer.t
    -> unit
end
