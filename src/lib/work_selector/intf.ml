open Core
open Currency

module type Transaction_snark_work_intf = sig
  type t

  val fee : t -> Fee.t

  val prover : t -> Signature_lib.Public_key.Compressed.t
end

module type Inputs_intf = sig
  module Ledger_hash : sig
    type t
  end

  module Sparse_ledger : sig
    type t
  end

  module Transaction : sig
    type t

    val yojson_summary : t -> Yojson.Safe.t
  end

  module Transaction_witness : sig
    type t

    val transaction : t -> Transaction.t
  end

  module Ledger_proof : sig
    type t

    module Stable : sig
      module Latest : sig
        type nonrec t = t
      end
    end

    module Cached : sig
      type t

      val read_proof_from_disk : t -> Stable.Latest.t
    end
  end

  module Transaction_snark_work : sig
    include Transaction_snark_work_intf

    module Statement : sig
      type t = Transaction_snark.Statement.t One_or_two.t
    end

    module Checked : Transaction_snark_work_intf
  end

  module Snark_pool : sig
    type t

    val get_completed_work :
         t
      -> Transaction_snark.Statement.t One_or_two.t
      -> Transaction_snark_work.Checked.t option
  end

  module Transaction_protocol_state : sig
    type 'a t
  end

  module Staged_ledger : sig
    type t

    (** A unit of pending work. Selection needs only its statement; the
        witness-bearing proving spec is built separately. *)
    module Available_job : sig
      type t
    end

    (** Enumerate the pending work as raw jobs; selection reads only their
        statements. *)
    val all_work_jobs : t -> Available_job.t One_or_two.t list

    (** The statement of a job (all selection/dedup needs); [None] only if a
        merge job's sub-statements fail to merge. *)
    val statement_of_job :
      Available_job.t -> Transaction_snark.Statement.t option

    (** The transaction of a base job (for log summaries); [None] for merge. *)
    val job_transaction : Available_job.t -> Transaction.t option

    (** Build the full proving spec (statement and witness) for one job — the
        witness is needed only to prove, so this is called when a job is
        dispatched to a worker. *)
    val single_spec_of_job :
         get_state:
           (Mina_base.State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
      -> Available_job.t
      -> ( Transaction_witness.t
         , Ledger_proof.Cached.t )
         Snark_work_lib.Work.Single.Spec.t
         Or_error.t
  end

  module Transition_frontier : sig
    type t

    type best_tip_view

    val best_tip_pipe : t -> best_tip_view Pipe_lib.Broadcast_pipe.Reader.t

    val best_tip_staged_ledger : t -> Staged_ledger.t

    val get_protocol_state :
      t -> Mina_base.State_hash.t -> Mina_state.Protocol_state.value Or_error.t
  end
end

module type State_intf = sig
  type t

  type transition_frontier

  val init :
       frontier_broadcast_pipe:
         transition_frontier option Pipe_lib.Broadcast_pipe.Reader.t
    -> logger:Logger.t
    -> t
end

module type Lib_intf = sig
  module Inputs : Inputs_intf

  open Inputs

  module State : sig
    include
      State_intf with type transition_frontier := Inputs.Transition_frontier.t

    (** A selectable unit of work: its statement (all the selector needs) plus
        the job(s) to build a proving spec from if it is dispatched. Opaque to
        the selection methods, which pick one and hand it to
        [schedule_and_build_spec]. *)
    type candidate

    (** [all_unscheduled_expensive_works ~snark_pool ~fee t] returns the
        candidates that are not scheduled yet and whose statement is not already
        proved more cheaply in the pool (see [does_not_have_better_fee]). *)
    val all_unscheduled_expensive_works :
      snark_pool:Snark_pool.t -> fee:Fee.t -> t -> candidate list

    (** Mark the chosen [candidate] scheduled and build its proving spec — the
        one point a job's witness is needed. [None] if the spec cannot be
        built. *)
    val schedule_and_build_spec :
         logger:Logger.t
      -> t
      -> candidate
      -> ( Transaction_witness.t
         , Ledger_proof.Cached.t )
         Snark_work_lib.Work.Single.Spec.t
         One_or_two.t
         option
  end

  (**jobs that are not in the snark pool yet*)
  val pending_work_statements :
       snark_pool:Snark_pool.t
    -> fee_opt:Fee.t option
    -> State.t
    -> Transaction_snark.Statement.t One_or_two.t list

  module For_tests : sig
    (** [does_not_have_better_fee ~snark_pool ~fee stmt] returns true iff the
        statement [stmt] haven't already been proved already in [snark_pool] or
        it's been proved with a fee higher than ~fee. The reason for the later
        condition is that the whole protocol would drop proofs with higher fees
        if there's a equivalent proof with lower fees *)
    val does_not_have_better_fee :
         snark_pool:Snark_pool.t
      -> fee:Fee.t
      -> Transaction_snark_work.Statement.t
      -> bool
  end
end

module type Selection_method_intf = sig
  type snark_pool

  type staged_ledger

  type work

  type transition_frontier

  module State : State_intf with type transition_frontier := transition_frontier

  val work :
       snark_pool:snark_pool
    -> fee:Currency.Fee.t
    -> logger:Logger.t
    -> State.t
    -> work One_or_two.t option
end

module type Make_selection_method_intf = functor (Lib : Lib_intf) ->
  Selection_method_intf
    with type staged_ledger := Lib.Inputs.Staged_ledger.t
     and type work :=
      ( Lib.Inputs.Transaction_witness.t
      , Lib.Inputs.Ledger_proof.Cached.t )
      Snark_work_lib.Work.Single.Spec.t
     and type snark_pool := Lib.Inputs.Snark_pool.t
     and type transition_frontier := Lib.Inputs.Transition_frontier.t
     and module State := Lib.State
