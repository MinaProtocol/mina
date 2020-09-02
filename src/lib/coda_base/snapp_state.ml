open Pickles_types
module Max_state_size = Nat.N4
include Vector.With_length (Max_state_size)

let typ t = Vector.typ t Max_state_size.n

open Core_kernel

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Snapp_basic.F.Stable.V1.t Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end
