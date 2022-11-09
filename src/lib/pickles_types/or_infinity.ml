[@@@warning "-4"]

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = Infinity | Finite of 'a
    [@@deriving sexp, equal, compare, hash, yojson]
  end
end]

[@@@warning "+4"]

let finite_exn = function
  | Finite x ->
      x
  | Infinity ->
      failwith "curve point must not be the point at infinity"
