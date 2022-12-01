open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }
    [@@deriving sexp, compare, equal, yojson, hash]
  end
end]

let create t = { inner = t }

let typ f =
  let there { inner = x } = x in
  let back x = create x in
  Snarky_backendless.Typ.(transport_var (transport f ~there ~back) ~there ~back)

let map { inner = x } ~f = create (f x)
