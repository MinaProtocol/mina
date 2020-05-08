open Pickles_types

type t = (Nat.N2.n, Nat.N2.n) Pickles.Proof.t [@@deriving sexp, yojson]

val dummy : t

[%%versioned:
module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving compare, sexp, yojson]
  end
end]
