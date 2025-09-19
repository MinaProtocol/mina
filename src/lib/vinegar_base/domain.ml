open Core_kernel

[@@@warning "-4"] (* sexp-related fragile pattern-matching warning *)

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Pow_2_roots_of_unity of int
    [@@unboxed] [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

[@@@warning "+4"]

include Hashable.Make (Stable.Latest)

let log2_size (Pow_2_roots_of_unity k) = k

let size t = 1 lsl log2_size t
