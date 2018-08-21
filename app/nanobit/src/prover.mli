open Core
open Async
open Nanobit_base
open Blockchain_snark

module type S = sig
  module Consensus_mechanism :
    Consensus.Mechanism.S with type Proof.t = Proof.t

  module Blockchain :
    Blockchain.S with module Consensus_mechanism = Consensus_mechanism

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
    -> Consensus_mechanism.Snark_transition.value
    -> Blockchain.t Deferred.Or_error.t
end

module Make
    (Consensus_mechanism : Consensus.Mechanism.S with type Proof.t = Proof.t)
    (Blockchain : Blockchain.S
                  with module Consensus_mechanism = Consensus_mechanism) :
  S
  with module Consensus_mechanism = Consensus_mechanism
   and module Blockchain = Blockchain
