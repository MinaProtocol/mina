open Signature_lib

type t = Set_delegate of {new_delegate: Public_key.Compressed.t}
[@@deriving bin_io, eq, sexp, hash]
