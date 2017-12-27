open Core_kernel

type t = Todo [@@deriving bin_io, sexp]
