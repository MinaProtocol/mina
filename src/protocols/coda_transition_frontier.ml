module type Transition_frontier_intf = sig
  type state_hash

  type external_transition

  type merkle_ledger

  type merkle_mask

  exception Parent_not_found of [`Parent of state_hash] * [`Target of state_hash]
  exception Already_exists of state_hash

  val max_length : int

  module Breadcrumb : sig
    type t

    val transition : t -> external_transition

    val mask : t -> merkle_mask
  end

  type t

  val create : root:external_transition -> ledger:merkle_ledger -> t

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

  val add_exn : t -> external_transition -> Breadcrumb.t
end

module type Catchup_intf = sig
  type external_transition

  type transition_frontier

  val run :
       frontier:transition_frontier
    -> catchup_job_reader:external_transition Linear_pipe.Reader.t
    -> unit
end

module type Transition_handler_intf = sig
  type external_transition

  type transition_frontier

  module Validator : sig
    val run :
         transition_reader:external_transition Linear_pipe.Reader.t
      -> valid_transition_writer:external_transition Linear_pipe.Writer.t
      -> unit
  end

  module Processor : sig
    val run :
         frontier:transition_frontier
      -> valid_transition_reader:external_transition Linear_pipe.Reader.t
      -> catchup_job_writer:external_transition Linear_pipe.Writer.t
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
    -> sync_query_reader:syncable_ledger_query Linear_pipe.Reader.t
    -> sync_answer_writer:syncable_ledger_answer Linear_pipe.Writer.t
    -> unit
end

module type Transition_frontier_controller_intf = sig
  type external_transition

  type syncable_ledger_query

  type syncable_ledger_answer

  type transition_frontier

  val run :
       frontier:transition_frontier
    -> transition_reader:external_transition Linear_pipe.Reader.t
    -> sync_query_reader:syncable_ledger_query Linear_pipe.Reader.t
    -> sync_answer_writer:syncable_ledger_answer Linear_pipe.Writer.t
    -> unit
end
