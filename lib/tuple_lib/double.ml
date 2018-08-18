open Core

type 'a t = 'a * 'a
[@@deriving bin_io, sexp, eq, compare]


