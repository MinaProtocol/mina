open Core_kernel

type t = string [@@deriving eq, sexp, yojson, bin_io]

let of_string s = s
