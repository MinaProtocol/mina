open Core
open Async
open Coda_base
open Blockchain_snark

module type S = sig
  type t

  val create : conf_dir:string -> logger:Logger.t -> t Deferred.t

  val extend_blockchain :
       t
    -> Blockchain.t
    -> Consensus.Mechanism.Protocol_state.value
    -> Consensus.Mechanism.Snark_transition.value
    -> Consensus.Mechanism.Prover_state.t
    -> Blockchain.t Deferred.t
end

include S
