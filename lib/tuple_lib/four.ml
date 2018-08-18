open Core

type t =
  | Zero
  | One 
  | Two
  | Three
[@@deriving sexp, eq, bin_io, hash]
