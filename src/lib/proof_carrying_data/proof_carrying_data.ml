(* A convenient data structure to bundle statements along with their proofs together *)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('a, 'b) t = { data : 'a; proof : 'b } [@@deriving sexp, fields]
  end
end]

let map { data; proof } ~f = { data = f data; proof }
