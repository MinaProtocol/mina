open Core_kernel

type t = Every_n_blocks of {n: int; prev: Coda_numbers.Length.t} | Never
[@@deriving sexp]
