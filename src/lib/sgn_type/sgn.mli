open Core_kernel

type t = Pos | Neg [@@deriving sexp, bin_io, hash, compare, eq, yojson]
