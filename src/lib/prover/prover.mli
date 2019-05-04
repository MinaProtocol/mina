open Async
open Coda_base
open Coda_state
open Blockchain_snark

module type S = sig
  module Worker_state : sig
    type t

    val create : unit -> t Deferred.t
  end

  type t

  val create : conf_dir:string -> t Deferred.t

  val initialized : t -> [`Initialized] Deferred.Or_error.t

  val extend_blockchain :
       t
    -> Blockchain.t
    -> Protocol_state.Value.t
    -> Snark_transition.value
    -> Consensus.Data.Prover_state.t
    -> Pending_coinbase_witness.t
    -> Blockchain.t Deferred.Or_error.t
end

include S
