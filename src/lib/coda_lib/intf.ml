open Core_kernel
open Async_kernel
open Coda_base
open Coda_state
open Pipe_lib
open Strict_pipe
open Signature_lib
open Otp_lib

module type Transaction_pool_read = sig
  type t

  type transaction_with_valid_signature

  val transactions : t -> transaction_with_valid_signature Sequence.t
end

module type Transaction_pool = sig
  include Transaction_pool_read

  type pool_diff

  type transaction

  type transition_frontier

  val broadcasts : t -> pool_diff Linear_pipe.Reader.t

  val load :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> disk_location:string
    -> incoming_diffs:pool_diff Envelope.Incoming.t Linear_pipe.Reader.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> t Deferred.t

  val add : t -> transaction -> unit Deferred.t
end

module type Snark_pool = sig
  type t

  type completed_work_statement

  type completed_work_checked

  type pool_diff

  type transition_frontier

  val broadcasts : t -> pool_diff Linear_pipe.Reader.t

  val load :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> disk_location:string
    -> incoming_diffs:pool_diff Envelope.Incoming.t Linear_pipe.Reader.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> t Deferred.t

  val get_completed_work :
    t -> completed_work_statement -> completed_work_checked option
end

module type Proposer = sig
  type staged_ledger

  type breadcrumb

  type completed_work_statement

  type completed_work_checked

  type transition_frontier

  type transaction_pool

  type verifier

  val run :
       logger:Logger.t
    -> verifier:verifier
    -> trust_system:Trust_system.t
    -> get_completed_work:(   completed_work_statement
                           -> completed_work_checked option)
    -> transaction_pool:transaction_pool
    -> time_controller:Block_time.Controller.t
    -> keypairs:( Agent.read_only Agent.flag
                , Keypair.And_compressed_pk.Set.t )
                Agent.t
    -> consensus_local_state:Consensus.Data.Local_state.t
    -> frontier_reader:transition_frontier option Broadcast_pipe.Reader.t
    -> transition_writer:( breadcrumb
                         , synchronous
                         , unit Deferred.t )
                         Strict_pipe.Writer.t
    -> unit
end

module type Subscriptions = sig end

module type Inputs = sig
  include Coda_intf.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t

  module Transition_frontier_persistence :
    Transition_frontier_persistence.Intf.S
    with type frontier := Transition_frontier.t
     and type verifier := Verifier.t

  module Transaction_pool :
    Transaction_pool
    with type transaction_with_valid_signature :=
                User_command.With_valid_signature.t
     and type transaction := User_command.t
     and type transition_frontier := Transition_frontier.t

  module Snark_pool :
    Snark_pool
    with type completed_work_statement := Transaction_snark_work.Statement.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type transition_frontier := Transition_frontier.t

  module State_body_hash : sig
    type t
  end

  module Net :
    Coda_intf.Network_intf
    with type external_transition := External_transition.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type snark_pool_diff = Snark_pool.pool_diff
     and type transaction_pool_diff = Transaction_pool.pool_diff

  module Transition_router :
    Coda_intf.Transition_router_intf
    with type external_transition := External_transition.t
     and type external_transition_verified := External_transition.Validated.t
     and type transition_frontier := Transition_frontier.t
     and type network := Net.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type verifier := Verifier.t

  module Root_prover :
    Coda_intf.Root_prover_intf
    with type transition_frontier := Transition_frontier.t
     and type external_transition := External_transition.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type verifier := Verifier.t

  module Proposer :
    Proposer
    with type staged_ledger := Staged_ledger.t
     and type completed_work_statement := Transaction_snark_work.Statement.t
     and type completed_work_checked := Transaction_snark_work.Checked.t
     and type transition_frontier := Transition_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type transaction_pool := Transaction_pool.t
     and type verifier := Verifier.t

  module Genesis : sig
    val state : (Protocol_state.Value.t, State_hash.t) With_hash.t

    val ledger : Ledger.maskable_ledger

    val proof : Proof.t
  end

  module Sync_handler :
    Coda_intf.Sync_handler_intf
    with type external_transition := External_transition.t
     and type external_transition_validated := External_transition.Validated.t
     and type transition_frontier := Transition_frontier.t
     and type parallel_scan_state := Staged_ledger.Scan_state.t

  module Work_selector :
    Work_selector.Intf.S
    with type snark_pool := Snark_pool.t
     and type fee := Currency.Fee.t
     and type staged_ledger := Staged_ledger.t
     and type work :=
                ( Transaction_snark.Statement.t
                , Transaction.t
                , Transaction_witness.t
                , Ledger_proof.t )
                Snark_work_lib.Work.Single.Spec.t

  (* TODO: Remove once the external_transition is not a functor parameter anymore *)
  module Filtered_external_transition : sig
    type t

    val of_transition :
         tracked_participants:Public_key.Compressed.Set.t
      -> (External_transition.Validated.t, 'a) With_hash.t
      -> (t, Staged_ledger.Pre_diff_info.Error.t) result

    val participants : t -> Public_key.Compressed.Set.t

    val user_commands : t -> User_command.t list
  end

  module External_transition_database :
    Auxiliary_database.Intf.External_transition
    with type filtered_external_transition := Filtered_external_transition.t
     and type time := Block_time.Stable.V1.t
     and type hash := State_hash.t
end
