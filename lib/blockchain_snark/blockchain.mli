module State = Blockchain_state
open Core_kernel
open Async_kernel
open Nanobit_base
open Snark_params

module type S = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  type t = {state: Consensus_mechanism.Protocol_state.value; proof: Proof.Stable.V1.t}
  [@@deriving bin_io, fields]

  val create : state:Consensus_mechanism.Protocol_state.value -> proof:Proof.Stable.V1.t -> t
end

module Make
    (Consensus_mechanism : Consensus.Mechanism.S)
  : S with module Consensus_mechanism = Consensus_mechanism
