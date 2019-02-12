module State = Blockchain_state
open Core_kernel
open Coda_base

module type S = sig
  type t = {state: Consensus.Protocol_state.value; proof: Proof.Stable.V1.t}
  [@@deriving bin_io, fields]

  val create :
    state:Consensus.Protocol_state.value -> proof:Proof.Stable.V1.t -> t
end

module Protocol_state = Consensus.Protocol_state

module Stable = struct
  module V1 = struct
    type t = {state: Protocol_state.value; proof: Proof.Stable.V1.t}
    [@@deriving bin_io, fields]
  end
end

include Stable.V1

let create ~state ~proof = {state; proof}
