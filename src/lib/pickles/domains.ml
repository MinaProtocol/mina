open Core_kernel

type t = {h: Domain.t; k: Domain.t; x: Domain.t}
[@@deriving fields, bin_io, sexp]
