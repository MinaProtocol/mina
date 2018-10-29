open Core_kernel

type 'a t = 'a * 'a * 'a * 'a [@@deriving bin_io, sexp, eq, compare]

let get ((x0, x1, x2, x3) : 'a t) (i : Four.t) =
  match i with Zero -> x0 | One -> x1 | Two -> x2 | Three -> x3
