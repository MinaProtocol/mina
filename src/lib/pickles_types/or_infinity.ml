open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = Infinity | Finite of 'a
    [@@deriving sexp, eq, compare, hash, yojson]
  end
end]

let finite_exn = function Finite x -> x | Infinity -> failwith "finite_exn"
