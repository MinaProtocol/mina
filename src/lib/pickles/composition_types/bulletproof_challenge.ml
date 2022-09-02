open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'challenge t =
          'challenge Mina_wire_types.Pickles_bulletproof_challenge.V1.t =
      { prechallenge : 'challenge }
    [@@deriving sexp, compare, yojson, hash, equal]
  end
end]

let pack { prechallenge } = prechallenge

let unpack = function prechallenge -> { prechallenge }

let typ chal =
  let there { prechallenge } = prechallenge in
  let back prechallenge = { prechallenge } in
  let open Snarky_backendless in
  Typ.transport ~there ~back (Kimchi_backend_common.Scalar_challenge.typ chal)
  |> Typ.transport_var ~there ~back
