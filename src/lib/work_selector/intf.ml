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
  end

  module Transaction_witness : sig
    type t
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

    val all_work_pairs :
         t
      -> get_state:
           (Mina_base.State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
      -> ( Transaction_witness.t
         , Ledger_proof.Cached.t )
         Snark_work_lib.Work.Single.Spec.t
         One_or_two.t
         list
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
       reassignment_wait:int
    -> frontier_broadcast_pipe:
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

    val remove_old_assignments : t -> logger:Logger.t -> unit

    (**Jobs that have not been assigned yet*)
    val all_unseen_works :
         t
      -> ( Transaction_witness.t
         , Ledger_proof.Cached.t )
         Snark_work_lib.Work.Single.Spec.t
         One_or_two.t
         list

    val remove : t -> Transaction_snark.Statement.t One_or_two.t -> unit

    val set :
         t
      -> ( Transaction_witness.t
         , Ledger_proof.Cached.t )
         Snark_work_lib.Work.Single.Spec.t
         One_or_two.t
      -> unit
  end

  (** [get_expensive_work ~snark_pool ~fee works] filters out all works in the
      list that satisfy the predicate
      [does_not_have_better_fee ~snark_pool ~fee] *)
  val get_expensive_work :
       snark_pool:Snark_pool.t
    -> fee:Fee.t
    -> ( Transaction_witness.t
       , Ledger_proof.Cached.t )
       Snark_work_lib.Work.Single.Spec.t
       One_or_two.t
       list
    -> ( Transaction_witness.t
       , Ledger_proof.Cached.t )
       Snark_work_lib.Work.Single.Spec.t
       One_or_two.t
       list

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
