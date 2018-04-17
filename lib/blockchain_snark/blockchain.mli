open Core_kernel
open Async_kernel
open Nanobit_base
open Snark_params

module State = Blockchain_state

type t =
  { state : State.t
  ; proof : Proof.t
  }
[@@deriving fields]

module Stable : sig
  module V1 : sig
    type nonrec t = t =
      { state : State.Stable.V1.t
      ; proof : Proof.Stable.V1.t
      }
    [@@deriving bin_io]
  end
end
