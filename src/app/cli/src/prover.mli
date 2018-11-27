open Core
open Async
open Coda_base
open Blockchain_snark

module type S = sig
  (* module Consensus_mechanism : Consensus.Mechanism.S

  module Blockchain :
    Blockchain.S with module Consensus_mechanism = Consensus_mechanism *)
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
    -> Consensus.Mechanism.Protocol_state.value
    -> Consensus.Mechanism.Snark_transition.value
    -> Consensus.Mechanism.Prover_state.t
    -> Blockchain.t Deferred.Or_error.t
end

include S
