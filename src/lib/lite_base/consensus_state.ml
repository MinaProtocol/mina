open Fold_lib

type t = {length: Length.t; signer_public_key: Public_key.Compressed.t}
[@@deriving eq, bin_io, sexp]

let length_in_triples =
  Length.length_in_triples + Public_key.Compressed.length_in_triples

let fold {length; signer_public_key} =
  Fold.(Length.fold length +> Public_key.Compressed.fold signer_public_key)
