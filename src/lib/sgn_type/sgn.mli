open Core_kernel

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Pos | Neg [@@deriving sexp, hash, compare, eq, yojson]
  end
end]
