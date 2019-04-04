(* TODO: check if this is needed *)
module State = Blockchain_state
open Core_kernel
open Coda_base

module type S = sig
  type t = {state: Consensus.Protocol_state.Value.t; proof: Proof.Stable.V1.t}
  [@@deriving bin_io, fields]

  val create :
    state:Consensus.Protocol_state.Value.t -> proof:Proof.Stable.V1.t -> t
end

include S
