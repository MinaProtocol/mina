open Core_kernel
open Async
open Nanobit_base

module State = Blockchain_state

module Stable = struct
  module V1 = struct
    type t =
      { state             : State.Stable.V1.t
      ; proof             : Proof.Stable.V1.t
      }
    [@@deriving bin_io]
  end
end

include Stable.V1
