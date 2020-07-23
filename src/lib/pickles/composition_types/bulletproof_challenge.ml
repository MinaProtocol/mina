type ('challenge, 'bool) t = {prechallenge: 'challenge; is_square: 'bool}
[@@deriving bin_io, sexp, compare, yojson]

let pack {prechallenge; is_square} = is_square :: prechallenge

let unpack = function
  | is_square :: prechallenge ->
      {is_square; prechallenge}
  | _ ->
      failwith "Bulletproof_challenge.unpack"

let typ chal bool =
  let there {prechallenge; is_square} = (prechallenge, is_square) in
  let back (prechallenge, is_square) = {prechallenge; is_square} in
  let open Snarky in
  Typ.transport ~there ~back
    (Typ.tuple2 (Pickles_types.Scalar_challenge.typ chal) bool)
  |> Typ.transport_var ~there ~back
