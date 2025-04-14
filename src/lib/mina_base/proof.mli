open Pickles_types

type t = (Nat.N3.n, Nat.N3.n) Pickles.Proof.t [@@deriving sexp, compare, yojson]

val blockchain_dummy : t lazy_t

val transaction_dummy : t lazy_t

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type nonrec t = t [@@deriving compare, sexp, yojson]

    val to_yojson_full : t -> Yojson.Safe.t
  end
end]

val to_yojson_full : t -> Yojson.Safe.t
