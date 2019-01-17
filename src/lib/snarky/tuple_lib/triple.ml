open Core_kernel

type 'a t = 'a * 'a * 'a [@@deriving bin_io, sexp, eq, compare]
