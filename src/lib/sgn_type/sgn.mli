open Core_kernel

type t = Pos | Neg [@@deriving sexp, hash, compare, eq, yojson]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving sexp, bin_io, hash, compare, eq, yojson, version]
  end

  module Latest = V1
end
