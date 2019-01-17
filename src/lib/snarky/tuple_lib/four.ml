open Core_kernel

type t = Zero | One | Two | Three [@@deriving sexp, eq, bin_io, hash]

let of_bits_lsb : bool Double.t -> t = function
  | false, false -> Zero
  | true, false -> One
  | false, true -> Two
  | true, true -> Three
