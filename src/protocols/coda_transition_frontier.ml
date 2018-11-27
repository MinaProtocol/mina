open Pipe_lib.Strict_pipe

module type Transition_frontier_intf = sig
  type state_hash

  type external_transition

  type base_db

  type staged_ledger

  exception Parent_not_found of ([`Parent of state_hash] * [`Target of state_hash])
  exception Already_exists of state_hash

  val max_length : int

  module Breadcrumb : sig
    type t

    val mask : t -> staged_ledger

    val transition : t -> (external_transition, state_hash) With_hash.t
  end

  type t

  val create :
       root:(external_transition, state_hash) With_hash.t
    -> ledger:merkle_ledger
    -> t

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

  val add_exn :
    t -> (external_transition, state_hash) With_hash.t -> Breadcrumb.t
end

module type Catchup_intf = sig
  type state_hash

  type external_transition

  type transition_frontier

  val run :
       frontier:transition_frontier
    -> catchup_job_reader:(external_transition, state_hash) With_hash.t
                          Reader.t
    -> unit
end

module type Transition_handler_intf = sig
  type state_hash

  type external_transition

  type transition_frontier

  module Validator : sig
    val run :
         transition_reader:external_transition Reader.t
      -> valid_transition_writer:( (external_transition, state_hash) With_hash.t
                                 , drop_head buffered
                                 , _ )
                                 Writer.t
      -> unit
  end

  module Processor : sig
    val run :
         frontier:transition_frontier
      -> valid_transition_reader:(external_transition, state_hash) With_hash.t
                                 Reader.t
      -> catchup_job_writer:( (external_transition, state_hash) With_hash.t
                            , drop_head buffered
                            , _ )
                            Writer.t
      -> unit
  end
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
    -> sync_query_reader:syncable_ledger_query Reader.t
    -> sync_answer_writer:(syncable_ledger_answer, synchronous, _) Writer.t
    -> unit
end

module type Transition_frontier_controller_intf = sig
  type external_transition

  type syncable_ledger_query

  type syncable_ledger_answer

  type transition_frontier

  val run :
       genesis_transition:external_transition
    -> transition_reader:external_transition Reader.t
    -> sync_query_reader:syncable_ledger_query Reader.t
    -> sync_answer_writer:(syncable_ledger_answer, synchronous, _) Writer.t
    -> unit
end
