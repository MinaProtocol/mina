open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'challenge t = {prechallenge: 'challenge}
    [@@deriving sexp, compare, yojson, hash, eq]
  end
end]

let pack {prechallenge} = prechallenge

let unpack = function prechallenge -> {prechallenge}

let typ chal =
  let there {prechallenge} = prechallenge in
  let back prechallenge = {prechallenge} in
  let open Snarky_backendless in
  Typ.transport ~there ~back (Pickles_types.Scalar_challenge.typ chal)
  |> Typ.transport_var ~there ~back
