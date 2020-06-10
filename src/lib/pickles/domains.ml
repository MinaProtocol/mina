open Core_kernel
open Import

type t = {h: Domain.t; k: Domain.t; x: Domain.t}
[@@deriving fields, bin_io, sexp]
