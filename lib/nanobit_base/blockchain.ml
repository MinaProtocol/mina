open Core_kernel
open Async
open Util
open Snark_params

module State = Blockchain_state

type t =
  { state : State.t
  ; proof : Proof.t
  }
[@@deriving bin_io]
