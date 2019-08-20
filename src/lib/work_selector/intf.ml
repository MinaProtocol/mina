open Currency

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
  end

  module Transaction_snark_work : sig
    type t

    val fee : t -> Fee.t
  end

  module Snark_pool : sig
    type t

    val get_completed_work :
         t
      -> Transaction_snark.Statement.t list
      -> Transaction_snark_work.t option
  end

  module Staged_ledger : sig
    type t

    val all_work_pairs_exn :
         t
      -> ( ( Transaction.t
           , Transaction_witness.t
           , Ledger_proof.t )
           Snark_work_lib.Work.Single.Spec.t
         * ( Transaction.t
           , Transaction_witness.t
           , Ledger_proof.t )
           Snark_work_lib.Work.Single.Spec.t
           option )
         list
  end
end

module type State_intf = sig
  type t

  val init : reassignment_wait:int -> t
end

module type Lib_intf = sig
  module Inputs : Inputs_intf

  open Inputs

  module State : sig
    include State_intf

    val set :
         t
      -> ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
         * ( Transaction.t
           , Transaction_witness.t
           , Ledger_proof.t )
           Snark_work_lib.Work.Single.Spec.t
           option
      -> t
  end

  val pair_to_list :
       ( Transaction.t
       , Transaction_witness.t
       , Ledger_proof.t )
       Snark_work_lib.Work.Single.Spec.t
       * ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
         option
    -> ( Transaction.t
       , Transaction_witness.t
       , Ledger_proof.t )
       Snark_work_lib.Work.Single.Spec.t
       list

  val get_expensive_work :
       snark_pool:Snark_pool.t
    -> fee:Fee.t
    -> ( ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
       * ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
         option )
       list
    -> ( ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
       * ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
         option )
       list

  val all_works :
       logger:Logger.t
    -> Staged_ledger.t
    -> State.t
    -> ( ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
       * ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
         option )
       list

  module For_tests : sig
    val does_not_have_better_fee :
         snark_pool:Snark_pool.t
      -> fee:Fee.t
      -> ( Transaction.t
         , Transaction_witness.t
         , Ledger_proof.t )
         Snark_work_lib.Work.Single.Spec.t
         list
      -> bool
  end
end

module type Selection_method_intf = sig
  type snark_pool

  type staged_ledger

  type work

  module State : State_intf

  val work :
       snark_pool:snark_pool
    -> fee:Currency.Fee.t
    -> logger:Logger.t
    -> staged_ledger
    -> State.t
    -> work list * State.t
end

module type Make_selection_method_intf = functor
  (Inputs : Inputs_intf)
  (Lib : Lib_intf with module Inputs := Inputs)
  -> Selection_method_intf
     with type staged_ledger := Inputs.Staged_ledger.t
      and type work :=
                 ( Inputs.Transaction.t
                 , Inputs.Transaction_witness.t
                 , Inputs.Ledger_proof.t )
                 Snark_work_lib.Work.Single.Spec.t
      and type snark_pool := Inputs.Snark_pool.t
      and module State := Lib.State
