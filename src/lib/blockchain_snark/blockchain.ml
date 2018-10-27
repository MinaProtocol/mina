module State = Blockchain_state
open Core_kernel
open Coda_base

module type S = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  type t =
    {state: Consensus_mechanism.Protocol_state.value; proof: Proof.Stable.V1.t}
  [@@deriving bin_io, fields]

  val create :
       state:Consensus_mechanism.Protocol_state.value
    -> proof:Proof.Stable.V1.t
    -> t
end

module Make (Consensus_mechanism : Consensus.Mechanism.S) :
  S with module Consensus_mechanism = Consensus_mechanism = struct
  module Consensus_mechanism = Consensus_mechanism
  module Protocol_state = Consensus_mechanism.Protocol_state

  module Stable = struct
    module V1 = struct
      type t = {state: Protocol_state.value; proof: Proof.Stable.V1.t}
      [@@deriving bin_io, fields]
    end
  end

  include Stable.V1

  let create ~state ~proof = {state; proof}
end
