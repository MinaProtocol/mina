(* TODO: check if this is needed *)
module State = Blockchain_state
open Core_kernel
open Coda_base

module type S = sig
  type t =
    {state: Consensus.Mechanism.Protocol_state.value; proof: Proof.Stable.V1.t}
  [@@deriving bin_io, fields]

  val create :
       state:Consensus.Mechanism.Protocol_state.value
    -> proof:Proof.Stable.V1.t
    -> t
end

include S
