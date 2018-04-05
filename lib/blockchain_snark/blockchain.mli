open Core_kernel
open Async_kernel
open Nanobit_base
open Snark_params

module State = Blockchain_state

type t =
  { state             : State.t
  ; most_recent_block : Block.t
  ; proof             : Proof.t
  }

module Stable : sig
  module V1 : sig
    type nonrec t = t =
      { state : State.Stable.V1.t
      ; most_recent_block : Block.Stable.V1.t
      ; proof : Proof.Stable.V1.t
      }
    [@@deriving bin_io]
  end
end
