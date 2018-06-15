module State = Blockchain_state
open Core_kernel
open Async
open Nanobit_base

module Stable = struct
  module V1 = struct
    type t = {state: State.Stable.V1.t; proof: Proof.Stable.V1.t}
    [@@deriving bin_io, fields]
  end
end

include Stable.V1
