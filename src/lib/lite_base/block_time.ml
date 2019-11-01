(* block_time.ml *)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Nat.Inputs_64.Stable.V1.t Nat.T.Stable.V1.t
    [@@deriving eq, sexp, to_yojson, compare]

    let to_latest = Fn.id
  end
end]

include Nat.Make64 ()
