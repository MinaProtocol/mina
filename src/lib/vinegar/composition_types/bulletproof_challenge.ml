[%%versioned
module Stable = struct
  module V1 = struct
    type 'challenge t =
          'challenge Mina_wire_types.Vinegar_bulletproof_challenge.V1.t =
      { prechallenge : 'challenge }
    [@@deriving sexp, compare, yojson, hash, equal]
  end
end]

let pack { prechallenge } = prechallenge

let unpack prechallenge = { prechallenge }

let map { prechallenge } ~f = { prechallenge = f prechallenge }

let typ chal =
  let there = pack in
  let back = unpack in
  let open Kimchi_pasta_snarky_backend.Step_impl in
  Typ.transport ~there ~back (Kimchi_backend_common.Scalar_challenge.typ chal)
  |> Typ.transport_var ~there ~back

let wrap_typ chal =
  let there = pack in
  let back = unpack in
  let open Kimchi_pasta_snarky_backend.Wrap_impl in
  Typ.transport ~there ~back
    (Kimchi_backend_common.Scalar_challenge.wrap_typ chal)
  |> Typ.transport_var ~there ~back
