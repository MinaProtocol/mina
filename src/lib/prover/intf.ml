open Async_kernel
open Coda_base
open Coda_state
open Coda_transition
open Blockchain_snark

module type S = sig
  module Worker_state : sig
    type t

    val create : unit -> t Deferred.t
  end

  type t

  val create :
    logger:Logger.t -> pids:Child_processes.Termination.t -> t Deferred.t

  val initialized : t -> [`Initialized] Deferred.Or_error.t

  val extend_blockchain :
       t
    -> Blockchain.t
    -> Protocol_state.Value.t
    -> Snark_transition.value
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
end
