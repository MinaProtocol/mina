open Async_kernel
open Mina_base
open Mina_state
open Mina_block
open Blockchain_snark

module type S = sig
  module Worker_state : sig
    type t

    type init_arg

    val create : init_arg -> t Deferred.t
  end

  type t

  val create :
       logger:Logger.t
    -> ?enable_internal_tracing:bool
    -> ?internal_trace_filename:string
    -> pids:Child_processes.Termination.t
    -> conf_dir:string
    -> proof_level:Genesis_constants.Proof_level.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> commit_id:string
    -> unit
    -> t Deferred.t

  val initialized : t -> [ `Initialized ] Deferred.Or_error.t

  val extend_blockchain :
       t
    -> Blockchain.t
    -> Protocol_state.Value.t
    -> Snark_transition.value
    -> Ledger_proof.t option
    -> Consensus.Data.Prover_state.t
    -> Pending_coinbase_witness.t
    -> Blockchain.t Deferred.Or_error.t

  val prove :
       t
    -> prev_state:Protocol_state.Value.t
    -> prev_state_proof:Proof.t
    -> next_state:Protocol_state.Value.t
    -> Internal_transition.t
    -> Pending_coinbase_witness.t
    -> Proof.t Deferred.Or_error.t

  val create_genesis_block :
    t -> Genesis_proof.Inputs.t -> Blockchain.t Deferred.Or_error.t

  val toggle_internal_tracing : t -> bool -> unit Deferred.Or_error.t

  (* in ITN logger, sets the client port of daemon to send RPC requests to
     sets the process kind for the Itn logger to "prover"
  *)
  val set_itn_logger_data : t -> daemon_port:int -> unit Deferred.Or_error.t
end
