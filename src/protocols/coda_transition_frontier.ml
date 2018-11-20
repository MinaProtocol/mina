module type Transition_frontier_intf = sig
  type state_hash

  type external_transition

  type merkle_ledger

  module Breadcrumb : sig
    type t

    val transition : t -> (external_transition, state_hash) With_hash.t
  end

  type t

  val create : root:(external_transition, state_hash) With_hash.t -> ledger:merkle_ledger -> t

  val root : t -> Breadcrumb.t

  val best_tip : t -> Breadcrumb.t

  val path : t -> Breadcrumb.t -> state_hash list

  val get : t -> state_hash -> Breadcrumb.t

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list

  val successors_rec : t -> Breadcrumb.t -> Breadcrumb.t list

  val iter : t -> f:(Breadcrumb.t -> unit) -> unit

  val add_exn : t -> (external_transition, state_hash) With_hash.t -> Breadcrumb.t
end

module type Catchup_intf = sig
  type state_hash

  type external_transition

  type transition_frontier

  val run :
       frontier:transition_frontier
    -> catchup_job_reader:(external_transition, state_hash) With_hash.t Linear_pipe.Reader.t
    -> unit
end

module type Transition_handler_intf = sig
  type state_hash

  type external_transition

  type transition_frontier

  module Validator : sig
    val run :
         transition_reader:external_transition Linear_pipe.Reader.t
      -> valid_transition_writer:(external_transition, state_hash) With_hash.t Linear_pipe.Writer.t
      -> unit
  end

  module Processor : sig
    val run :
         frontier:transition_frontier
      -> valid_transition_reader:(external_transition, state_hash) With_hash.t Linear_pipe.Reader.t
      -> catchup_job_writer:(external_transition, state_hash) With_hash.t Linear_pipe.Writer.t
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

  val run :
       genesis_transition:external_transition
    -> transition_reader:external_transition Linear_pipe.Reader.t
    -> sync_query_reader:syncable_ledger_query Linear_pipe.Reader.t
    -> sync_answer_writer:syncable_ledger_answer Linear_pipe.Writer.t
    -> unit
end
