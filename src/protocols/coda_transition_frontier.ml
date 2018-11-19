module type Transition_frontier_intf = sig
  type state_hash

  type external_transition

  module Breadcrumb : sig
    type t

    val create : predecessor:t -> transition:external_transition -> t

    val transition : t -> external_transition
  end

  type t

  val create : unit -> t

  val get : t -> state_hash -> Breadcrumb.t

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list
end

module type Catchup_intf = sig
  type external_transition

  type transition_frontier

  val run :
       catchup_job_reader:external_transition Linear_pipe.Reader.t
    -> transition_frontier
    -> unit
end

module type Transition_handler_intf = sig
  type external_transition

  type transition_frontier

  module Validator : sig
    val run :
         transition_reader:external_transition Linear_pipe.Reader.t
      -> valid_transition_writer:external_transition Linear_pipe.Writer.t
      -> transition_frontier
      -> unit
  end

  module Processor : sig
    val run :
         valid_transition_reader:external_transition Linear_pipe.Reader.t
      -> catchup_job_writer:external_transition Linear_pipe.Writer.t
      -> transition_frontier
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
       sync_query_reader:syncable_ledger_query Linear_pipe.Reader.t
    -> sync_answer_writer:syncable_ledger_answer Linear_pipe.Writer.t
    -> transition_frontier
    -> unit
end

module type Transition_frontier_controller_intf = sig
  type external_transition

  type syncable_ledger_query

  type syncable_ledger_answer

  val run :
       transition_reader:external_transition Linear_pipe.Reader.t
    -> sync_query_reader:syncable_ledger_query Linear_pipe.Reader.t
    -> sync_answer_writer:syncable_ledger_answer Linear_pipe.Writer.t
    -> unit
end
