(* A convenient data structure to bundle statements along with their proofs together *)

open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('a, 'p) t = ('a, 'p) Mina_wire_types.Proof_carrying_data.V1.t =
      { data : 'a [@key "statement"]; proof : 'p }
    [@@deriving compare, equal, fields, hash, sexp, version, yojson]
  end
end]

let map { data; proof } ~f = { data = f data; proof }
