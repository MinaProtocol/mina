open Core_kernel
open Coda_base
open Coda_state

[%%versioned
module Stable = struct
  module V1 = struct
    type t = {state: Protocol_state.Value.Stable.V1.t; proof: Proof.Stable.V1.t}
    [@@deriving fields, sexp]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = {state: Protocol_state.Value.t; proof: Proof.t}
[@@deriving fields, sexp]

let create ~state ~proof = {state; proof}
