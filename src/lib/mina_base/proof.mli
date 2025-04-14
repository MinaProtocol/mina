open Pickles_types

type t = (Nat.N2.n, Nat.N2.n) Pickles.Proof.t [@@deriving sexp, compare, yojson]

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

module For_tests : sig
  val blockchain_dummy_tag : Proof_cache_tag.t lazy_t

  val transaction_dummy_tag : Proof_cache_tag.t lazy_t
end
