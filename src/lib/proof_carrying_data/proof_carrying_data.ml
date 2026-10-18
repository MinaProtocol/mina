(* A convenient data structure to bundle statements along with their proofs together *)

open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type ('a, 'p) t = ('a, 'p) Mina_wire_types.Proof_carrying_data.V1.t =
      { data : 'a [@key "statement"]; proof : 'p }
    [@@deriving compare, equal, fields, hash, sexp, version, yojson]
  end
end]

type ('a, 'p) t = ('a, 'p) Stable.Latest.t =
  { data : 'a [@key "statement"]; proof : 'p }
[@@deriving compare, equal, fields, hash, sexp, yojson]

let map { data; proof } ~f = { data = f data; proof }

let map_proof { data; proof } ~f = { data; proof = f proof }
