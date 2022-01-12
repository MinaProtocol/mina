open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = Infinity | Finite of 'a
    [@@deriving sexp, equal, compare, hash, yojson]
  end
end]

let finite_exn = function
  | Finite x ->
      x
  | Infinity ->
      failwith "curve point must not be the point at infinity"
