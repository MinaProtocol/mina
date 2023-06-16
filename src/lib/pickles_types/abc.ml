open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = { a : 'a; b : 'a; c : 'a }
    [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]

    (* TODO: sexp, compare, hash, yojson, hlist and fields seem unused *)
  end
end]

module Label = struct
  type t = A | B | C [@@deriving equal]

  let all = [ A; B; C ]
end
