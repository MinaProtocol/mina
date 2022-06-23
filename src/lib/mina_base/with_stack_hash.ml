open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('a, 'field) t = { elt : 'a; stack_hash : 'field }
    [@@deriving sexp, compare, equal, hash, yojson, fields, quickcheck]
  end
end]

let map t ~f = { t with elt = f t.elt }
