open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Pow_2_roots_of_unity of int
    [@@deriving version, eq, bin_io, sexp, compare]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = Pow_2_roots_of_unity of int
[@@deriving eq, sexp, compare]

let log2_size (Pow_2_roots_of_unity k) = k

let size t = 1 lsl log2_size t
