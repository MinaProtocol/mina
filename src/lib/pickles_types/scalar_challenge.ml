open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'f t = Scalar_challenge of 'f
    [@@deriving version, sexp, compare, eq, yojson, hash]
  end
end]

let create t = Scalar_challenge t

let typ f =
  let there (Scalar_challenge x) = x in
  let back x = Scalar_challenge x in
  Snarky_backendless.Typ.(
    transport_var (transport f ~there ~back) ~there ~back)

let map (Scalar_challenge x) ~f = Scalar_challenge (f x)
