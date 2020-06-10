type ('challenge, 'bool) t = {prechallenge: 'challenge; is_square: 'bool}
[@@deriving bin_io, sexp, compare, yojson]

let pack {prechallenge; is_square} = is_square :: prechallenge

let unpack = function
  | is_square :: prechallenge ->
      {is_square; prechallenge}
  | _ ->
      failwith "Bulletproof_challenge.unpack"
