open Core_kernel

type t = Todo [@@deriving bin_io, compare, sexp]
